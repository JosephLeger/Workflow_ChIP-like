#!/bin/env bash

################################################################################################################
### HELP -------------------------------------------------------------------------------------------------------
################################################################################################################
script_name='7_PeakyFinders.sh'

# Get user id for custom manual pathways
usr=`id | sed -e 's@).*@@g' | sed -e 's@.*(@@g'`

# Text font variables
END='\033[0m'
BOLD='\033[1m'
UDL='\033[4m'

# Show command manual
Help()
{
echo -e "${BOLD}####### PEAKYFINDER MANUAL #######${END}\n\n\
${BOLD}SYNTHAX${END}\n\
    sh ${script_name} [options] <chrom_size> <input_dir1> <...>\n\n\

${BOLD}DESCRIPTION${END}\n\
    Perform peak calling from BAM files using HOMER or MACS2.\n\
    Prepares tag files required for HOMER processing from BAM files, and performs peak calling.\n\
    Peaks thus called are saved in a .txt file, sorted and then saved in .bed .bedgraph and .bw files. \n\
    It creates new folders './HOMER/Tags/<tag_name>' and './HOMER/Peaks/<tag_name>' in which output files are stored.\n\n\

${BOLD}OPTIONS${END}\n\n\

${BOLD}Common Options${END}\n\
    ${BOLD}-N${END} ${UDL}suffix${END}, ${BOLD}N${END}amePattern\n\
        Define a suffix that input files must share to be considered. Allows to exclude BAM files that are unfiltered or unwanted.\n\
        Default = '_sorted_unique_filtered'\n\n\
    ${BOLD}-U${END} ${UDL}toolName${END}, ${BOLD}U${END}sedTool\n\
        Define tool used for peak calling. Must be in 'HOMER' or 'MACS2'.\n\
        Default = 'HOMER'\n\n\

${BOLD}HOMER Options${END}\n\
    ${BOLD}-S${END} ${UDL}size${END}, fragment${BOLD}S${END}ize\n\
        Define fragment size sequenced.\n\
        Default = auto\n\n\
    ${BOLD}-M${END} ${UDL}style${END}, ${BOLD}M${END}ode\n\
        Precise mode (HOMER -style) to use when running script.\n\
        Must be in 'factor', 'histone', 'super', 'groseq', 'tss', 'dnase' or 'mC'.\n\
        Default = factor\n\n\
    ${BOLD}-I${END} ${UDL}file${END}, ${BOLD}I${END}nputControl\n\
        NOT FUNCTIONNAL YET\n\
        THE IDEA IS TO PRECISE ORIGINATE BAM IGG FOLDER TO ASSUME FURTHER TAG FOLDER REQUIRED FOR THE COMMAND\n\
        Specify a folder containing input control BAM files to use as reference background noize for peak calling.\n\
        If setted, peaks are filtered based on threshold defined with -F option.\n\
        It usually correspond to IgG experiment. \n\
        Default = None\n\n\
    ${BOLD}-F${END} ${UDL}threshold${END}, ${BOLD}F${END}oldEnrichmentVersusInput\n\
        NOT FUNCTIONNAL YET\n\
        Define required fold change of experimental data compared to input control to consider peaks.\n\
        Default = 4\n\n\
    ${BOLD}-L${END} ${UDL}threshold${END}, ${BOLD}L${END}ocalFoldEnrichment\n\
        Define required fold change of a region compared to local signal (surrounding 10kb region) to consider peaks.\n\
        Default = 4\n\n\
    ${BOLD}-C${END} ${UDL}threshold${END}, ${BOLD}C${END}lonalFoldEnrichment\n\
        Define maximal ratio for the number of unique positions containing tags in a peak relative to the expected number of unique positions given the total number of tags in the peak.\n\
        For MNase or other restriction enzyme digestion, should be setted to 0.\n\
        Default = 2\n\n\
    ${BOLD}-T${END} ${UDL}threshold${END}, ${BOLD}T${END}agThreshold\n\
        Define required minimal tag value to consider peaks.\n\
        Default=2\n\n\

    For more details, please see HOMER manual \n\ 
    (http://homer.ucsd.edu/homer/ngs/peaks.html).\n\n\
    
${BOLD}MACS2 Options${END}\n\n\
    ${BOLD}-G${END} ${UDL}size${END}, ${BOLD}G${END}enomSize\n\
        \n\
        Default=1.87e9\n\n\
    ${BOLD}-H${END} ${UDL}integer${END}, S${BOLD}h${END}ift\n\
        \n\
        Default=50\n\n\
    ${BOLD}-E${END} ${UDL}integer${END}, ${BOLD}E${END}xtend\n\
        \n\
        Default=100\n\n\

${BOLD}ARGUMENTS${END}\n\
    ${BOLD}<chrom_size>${END}\n\
        Pathway to chromosome size file.\n\
        Could be downloaded on UCSC website (e.g. https://hgdownload.soe.ucsc.edu/goldenPath/mm39/bigZips/, 'mm39.chrom.sizes').\n\
        For HOMER usage, downloaded file have to be modified as following :\n\
            1) Remove 'chr' in front of chromosome names.\n\
            2) Remove everything before and after '_' for non-usual chromosomes names.\n\
            3) Replace 'v1' by '.1' in non-usual chromosme names.\n\
            4) Make sure entries are Tab separated.\n\n\
    ${BOLD}<input_dir>${END}\n\
        Directory containing .bam files to process.\n\
        It usually corresponds to 'Mapped/<model>/BAM'.\n\n\
    ${BOLD}<...>${END}\n\
        Several directories can be specified as argument in the same command line, allowing processing of multiple models simultaneously.\n\n\  

${BOLD}EXAMPLE USAGE${END}\n\
    sh ${script_name} -U 'HOMER' ${BOLD}-N${END} _unique_filtered ${BOLD}-S${END} 50 ${BOLD}-M${END} dnase ${BOLD}-I${END} none ${BOLD}-F${END} none ${BOLD}-L${END} 4 ${BOLD}-C${END} 2 ${BOLD}/LAB-DATA/BiRD/users/${usr}/Ref/Genome/mm39.chrom.sizes Mapped/mm39/BAM${END}\n"
}

################################################################################################################
### OPTIONS ----------------------------------------------------------------------------------------------------
################################################################################################################

# Set default values
N_arg='_sorted_filtered'
U_arg='HOMER'
S_arg='auto'
M_arg='factor'
I_arg='None' 
F_arg=4 
L_arg=4
C_arg=2
T_arg=2
#
G_arg=1.87e9
H_arg=50
E_arg=100


# Change default values if another one is precised
while getopts ":N:U:S:M:I:F:L:C:T:G:H:E:" option; do
    case $option in
        N) # NAME OF FILE (SUFFIX)
            N_arg=${OPTARG};;
        U) # USED TOOL FOR PEAK CALLING
            U_arg=${OPTARG};;
        S) # SIZE OF FRAGMENTS
            S_arg=${OPTARG};;
        M) # MODE TO RUN FIND PEAKS (STYLE)
            M_arg=${OPTARG};;
        I) # INPUT CONTROL (IgG)
            I_arg=${OPTARG};;
        F) # FOLD CHANGE THAN CONTROL THRESHOLD (IgG)
            F_arg=${OPTARG};;
        L) # LOCAL TAG FOLD CHANGE THRESHOLD
            L_arg=${OPTARG};;
        C) # CLONAL SIGNAL THRESHOLD
            C_arg=${OPTARG};;
        T) # TAG THRESHOLD
            T_arg=${OPTARG};;
        G) # MACS2 GENOME SIZE
            G_arg=${OPTARG};;
        H) # MACS2 SHIFT
            H_arg=${OPTARG};;
        E) # MAC2 EXTEND
            E_arg=${OPTARG};;
        \?) # Error
            echo "Error : invalid option"
            echo "      Allowed options are [-N|-U|-S|-M|-I|-F|-L|-C|-T|-G|-H|-E]"
            echo "      Enter 'sh ${script_name} help' for more details"
            exit;;
        esac
done

# Checking if provided option values are correct
case $I_arg in
    None|none|FALSE|False|false|F) 
        I_arg=''
        F_arg='';;
    *) 
        I_arg='-i '$I_arg
        F_arg='-F '$F_arg' ';;
esac
case $U_arg in
    HOMER|homer|Homer) 
        U_arg='HOMER';;
    MACS2|mac2|Macs2)
        U_arg='MACS2';;
    *) 
        echo "Error value : -U argument must be 'HOMER' or 'MACS2'"
        exit;;
esac

# Deal with options [-N|-U|-S|-M|-I|-F|-L|-C|-T] and arguments [$1|$2|...]
shift $((OPTIND-1))


################################################################################################################
### ERRORS -----------------------------------------------------------------------------------------------------
################################################################################################################

if [ $# -eq 1 ] && [ $1 == "help" ]; then
    Help
    exit
elif [ ${U_arg} == 'HOMER' ] && [ $# -lt 2 ]; then
    # Error if no input directory is provided
    echo "Error synthax : please use following synthax when using HOMER"
    echo "      sh ${script_name} [options] <chr_size_file> <input_dir1> <...>"
    exit
elif [ ${U_arg} == 'MACS2' ] && [ $# -lt 1 ]; then
    # Error if no input directory is provided
    echo "Error synthax : please use following synthax when using MACS2"
    echo "      sh ${script_name} [options] <chr_size_file> <input_dir1> <...>"
    exit
else
    # For each input file given as argument
    for input in "${@:2}"; do
        # Count .bam files in each provided directory
        files=$(shopt -s nullglob dotglob; echo ${input}/*${N_arg}*.bam)
        if (( !${#files} )); then
            # Error if current provided directory is empty or does not exists
            echo -e "Error : can not find files in ${input} directory. Please make sure the provided input directory exists, and contains .bam files"
            exit
        fi
    done
fi


################################################################################################################
### SCRIPT -----------------------------------------------------------------------------------------------------
################################################################################################################

module load samtools/1.15.1
module load bedtools/2.30.0
module load ucsc-bedgraphtobigwig/377

# Generate REPORT
echo '#' >> ./0K_REPORT.txt
date >> ./0K_REPORT.txt

if [ ${U_arg} == 'HOMER' ]; then
    module load homer/4.11
    # Create Tags output directories
    mkdir -p HOMER/Tags
    for input in "${@:2}"; do
        # Precise to eliminate empty lists for the loop
        shopt -s nullglob
        # For each matching BAM file in $input directory
        for i in ${input}/*${N_arg}*.bam; do
            # Genrate tag_name by removing pathway, suffix and .bam of read files
            current_tag=`echo $i | sed -e "s@$input\/@@g" | sed -e "s@${N_arg}@@g" | sed -e 's@\.bam@@g'`
            # Create Peaks output directories
            mkdir -p HOMER/Peaks/${current_tag}

            # Set variables for the run :
            tag_dir=HOMER/Tags/${current_tag}
            peaks_txt=HOMER/Peaks/${current_tag}/${current_tag}_peaks.txt
            peaks_bed=HOMER/Peaks/${current_tag}/${current_tag}_peaks_sorted.bed
            bedgraph=HOMER/Peaks/${current_tag}/${current_tag}_peaks_sorted.bedgraph
            bigwig=HOMER/Peaks/${current_tag}/${current_tag}_peaks_sorted.bw

            # Launch HOMER
            echo -e "#$ -V \n#$ -cwd \n#$ -S /bin/bash \n\
            makeTagDirectory ${tag_dir} $i -fragLength ${S_arg} -single \n\
            findPeaks ${tag_dir} -style ${M_arg} \
            -o ${peaks_txt} \
            -L ${L_arg} \
            -C ${C_arg} \
            -tagThreshold ${T_arg} ${I_arg}${F_arg}\n\
            grep -v '^#' ${peaks_txt} | awk -v OFS='\t' '{print \$2,\$3,\$4,\$1,\$8,\$5}' | bedtools sort > ${peaks_bed} \n\
            genomeCoverageBed -bga -i ${peaks_bed} -g ${1} | bedtools sort > ${bedgraph} \n\
            bedGraphToBigWig ${bedgraph} ${1} ${bigwig}" | qsub -N HOMER_${current_tag}
            # Update REPORT
            echo -e "HOMER_${current_tag} | makeTagDirectory ${tag_dir} $i -fragLength ${S_arg} -single" >> ./0K_REPORT.txt
            echo -e "        | findPeaks ${tag_dir} -style ${M_arg} -o ${peaks_txt} -L ${L_arg} -C ${C_arg} -tagThreshold ${T_arg} ${I_arg}${F_arg}" >> ./0K_REPORT.txt   
            echo -e "        | grep -v '^#' ${peaks_txt} | awk -v OFS='\t' '{print \$2,\$3,\$4,\$1,\$8,\$5}' | bedtools sort > ${peaks_bed}" >> ./0K_REPORT.txt  
            echo -e "        | genomeCoverageBed -bga -i ${peaks_bed} -g ${1} | bedtools sort > ${bedgraph}" >> ./0K_REPORT.txt  
            echo -e "        | bedGraphToBigWig ${bedgraph} ${1} ${bigwig}" >> ./0K_REPORT.txt  
        done
    done
elif [ ${U_arg} == 'MACS2' ]; then
    module load gcc
    module load macs2

    for input in "${@:1}"; do
        for file in ${input}/*${N_arg}*.bam; do    
            # Define current tag
            current_tag=`echo ${file} | sed -e "s@${input}/@@g" | sed -e "s@${N_arg}@@g" | sed -e 's@\.bam@@g'`
            # Create output dir
            newdir=MACS2/Peaks/${current_tag}
            mkdir -p ${newdir}

            # Set variables for the run :
            narrrow_peak=MACS2/Peaks/${current_tag}/${current_tag}_peaks.narrowPeak
            peaks_bed=MACS2/Peaks/${current_tag}/${current_tag}_peaks_sorted.bed
            bedgraph=MACS2/Peaks/${current_tag}/${current_tag}_peaks_sorted.bedgraph
            bigwig=MACS2/Peaks/${current_tag}/${current_tag}_peaks_sorted.bw
            
            # Launch MACS2
            echo -e "#$ -V \n#$ -cwd \n#$ -S /bin/bash \n\
            macs2 callpeak \
            -t ${file} \
            -f BAM -g ${G_arg} 
            --nomodel \
            --shift ${H_arg} \
            --extsize ${E_arg} \
            -n ${current_tag} \
            --outdir ${newdir}\n\
            grep -v '^#' ${narrow_peak} | awk -v OFS='\t' '{print \$1,\$2,\$3,\$4,\$5,\$6}' | bedtools sort > ${peaks_bed} \n\
            genomeCoverageBed -bga -i ${peaks_bed} -g ${1} | bedtools sort > ${bedgraph} \n\
            bedGraphToBigWig ${bedgraph} ${1} ${bigwig}" | qsub -N MACS2_${current_tag}
            # Update REPORT
            echo -e "MACS2_${current_tag} | macs2 callpeak -t ${file} -f BAM -g ${G_arg} --nomodel --shift ${H_arg} --extsize ${E_arg} -n ${current_tag} --outdir ${newdir}" >> ./0K_REPORT.txt
            echo -e "        | grep -v '^#' ${narrow_peak} | awk -v OFS='\t' '{print \$1,\$2,\$3,\$4,\$5,\$6}' | bedtools sort > ${peaks_bed}" >> ./0K_REPORT.txt  
            echo -e "        | genomeCoverageBed -bga -i ${peaks_bed} -g ${1} | bedtools sort > ${bedgraph}" >> ./0K_REPORT.txt  
            echo -e "        | bedGraphToBigWig ${bedgraph} ${1} ${bigwig}" >> ./0K_REPORT.txt  
        done
    done
fi
