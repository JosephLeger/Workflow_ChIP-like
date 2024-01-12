#!/bin/env bash

################################################################################################################
### HELP -------------------------------------------------------------------------------------------------------
################################################################################################################
script_name='BAM2BW'

# Get user id for custom manual pathways
usr=`id | sed -e 's@).*@@g' | sed -e 's@.*(@@g'`

# Text font variabes
END='\033[0m'
BOLD='\033[1m'
UDL='\033[4m'

# Show command manual
Help()
{
echo -e "${BOLD}####### BAM2BW MANUAL #######${END}\n\n\
${BOLD}SYNTHAX${END}\n\
    sh ${script_name} [options] <input_dir1> <...>\n\n\

${BOLD}DESCRIPTION${END}\n\
    Perform conversion of BAM files to Trace files in bigwig format using deeptools bamCoverage.\n\
    It creates a new folder 'Mapped/<model>/BIGWIG' in which output files are be stored.\n\n\
    
${BOLD}OPTIONS${END}\n\
    ${BOLD}-N${END} ${UDL}suffix${END}, ${BOLD}N${END}amePattern\n\
        Define a suffix that input files must share to be considered. Allows to exclude unwanted peak files.\n\
        Default = _sorted_unique_filtered\n\n\
    ${BOLD}-F${END} ${UDL}outFormat${END}, ${BOLD}F${END}ormat\n\
        Select output files format. Could be 'bigwig' or 'bedgraph'.\n\
        Default = bigwig\n\n\
    ${BOLD}-M${END} ${UDL}normalizationMethod${END}, Normalization${BOLD}M${END}ethod\n\
        Select nromalization method to apply. Could be 'RPKM', 'CPM', 'BPM', 'RPGC' or 'None'.\n\
        Default = None\n\n\
    ${BOLD}-R${END} ${UDL}boolean${END}, ${BOLD}R${END}emoveSuffix\n\
        Specify whether specified suffix from input filename have to be removed in output filename.\n\
        Default = false\n\n\

${BOLD}ARGUMENTS${END}\n\
    ${BOLD}<input_dir>${END}\n\
        Directory containing .bam files to process.\n\
        It usually corresponds to 'Mapped/<model>/BAM'.\n\n\
    ${BOLD}<...>${END}\n\
        Several directories can be specified as argument in the same command line, allowing processing of multiple models simultaneously.\n\n\  

${BOLD}EXAMPLE USAGE${END}\n\
    sh ${script_name} ${BOLD}-N${END} _sorted_unique_filtered ${BOLD}-F${END} bigwig ${BOLD}-M${END} RPKM ${BOLD}-R${END} true ${BOLD}Mapped/mm39/BAM${END}\n"
}

################################################################################################################
### OPTIONS ----------------------------------------------------------------------------------------------------
################################################################################################################

# Set default values
N_arg="_sorted_unique_filtered"
F_arg="bigwig"
M_arg="None"
R_arg="false"

# Change default values if another one is precised
while getopts ":N:F:M:R:" option; do
    case $option in
        N) # SUFFIX TO DISCRIMINATE FILES FOR INPUT
            N_arg=${OPTARG};;
        F) # FORMAT FOR OUTPUT FILE
            F_arg=${OPTARG};;
        M) # NORMALIZATION TO APPLY
            M_arg=${OPTARG};;
        R) # REMOVE SUFFIX IN OUTPUT FILENAME
            R_arg=${OPTARG};;
        \?) # Error
            echo "Error : invalid option"
            echo "      Allowed options are [-N|-F|-M|-R]"
            echo "      Enter sh Bam2BW.sh help for more details"
            exit;;
        esac
done

# Checking if provided option values are correct
case $F_arg in
    bedgraph|BedGraph) 
        F_arg="bedgraph"
        file_ext="bedgraph"
        out_dir="BEDGRAPH";;
    bigwig|BigWig|BW|bw)
        F_arg="bigwig"
        file_ext="bw"
        out_dir="BIGWIG";;
    *) 
        echo "Error value : -F argument must be 'bigwig' or 'bedgraph'"
        exit;;
esac
case $M_arg in
    RPKM|CPM|BPM|RPGC) 
        M_arg=${M_arg}
        NormName="_${M_arg}";;
    None)
        M_arg=${M_arg}
        NormName='';;
    *) 
        echo "Error value : -N argument must be in 'RPKM', 'CPM', 'BPM', 'RPGC' or 'None'"
        exit;;
esac
case $R_arg in
    true|TRUE|True|T) 
        R_arg='true';;
    false|FALSE|False|F)
        R_arg='false';;
    *) 
        echo "Error value : -R argument must be 'true' or 'false'"
        exit;;
esac

# Deal with options [-N|-F|-M|-R] and arguments [$1|$2|...]
shift $((OPTIND-1))

################################################################################################################
### ERRORS -----------------------------------------------------------------------------------------------------
################################################################################################################

if [ $# -eq 1 ] && [ $1 == "help" ]; then
    Help
    exit
elif [ $# == 0 ]; then
    # Error if no input directory is provided
    echo "Error synthax : please use following synthax"
    echo "      sh ${script_name} [options] <input_dir1> <...>"
    exit
else
    # For each input file given as argument
    for input in "$@"; do
        # Count .sam files in each provided directory
        files=$(shopt -s nullglob dotglob; echo ${input}/*${N_arg}*.bam)
        if (( !${#files} )); then
            # Error if current provided directory is empty or does not exists
            echo -e "Error : can not find files to sort in ${input} directory. Please make sure the provided input directory exists, and contains .bam files."
            exit
        fi
    done
fi

################################################################################################################
### SCRIPT -----------------------------------------------------------------------------------------------------
################################################################################################################

module load deeptools/3.5.0

for input in "$@"; do
    # Create output directory
    model=`echo ${input} | sed -e 's@.*Mapped\/@@g' | sed -e 's@\/.*@@g'`
    newdir='Mapped/'${model}'/'${out_dir}
    mkdir -p ${newdir}
    # Precise to eliminate empty lists for the loop
    shopt -s nullglob
    for i in ${input}/*${N_arg}*.bam; do
        # Set variables for jobname
        current_file=`echo $i | sed -e "s@${input}\/@@g" | sed -e 's@\.bam@@g'`
        if [ $R_arg == 'true' ]; then
            # Remove suffix if R_arg is specified to 'true'
            current_file=`echo ${current_file} | sed -e "s@${N_arg}@@g"`
        fi
        # Launch conversion to trace file in qsub
        echo -e "#$ -V \n#$ -cwd \n#$ -S /bin/bash \n\
        bamCoverage \
        --normalizeUsing $M_arg \
        --outFileFormat $F_arg \
        -b $i \
        -o ${newdir}'/'${current_file}${NormName}'.'${file_ext}" | qsub -N Bam2${F_arg}_${current_file}
    done
done
