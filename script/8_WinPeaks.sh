#!/bin/env bash

################################################################################################################
### HELP -------------------------------------------------------------------------------------------------------
################################################################################################################

# Get user id for custom manual pathways
usr=`id | sed -e 's@).*@@g' | sed -e 's@.*(@@g'`

# Text font variabes
END='\033[0m'
BOLD='\033[1m'
UDL='\033[4m'

# Show command manual
Help()
{
echo -e "${BOLD}####### WINPEAKS MANUAL #######${END}\n\n\
${BOLD}SYNTHAX${END}\n\
        sh WinPeaks.sh <input_dir> <fatsa_file> <gtf_file> <motif_file>\n\n\

${BOLD}DESCRIPTION${END}\n\
        Perform quality check of FASTQ files using FastQC.\n\
        It creates a new folder './QC/<input_dir>' in which quality check results are stored.\n\
        Output files are .html files for direct visualization and .zip files containing results.\n\n\

${BOLD}OPTIONS${END}\n\
    ${BOLD}-N${END} ${UDL}suffix${END}, ${BOLD}N${END}amePattern\n\
        Define a suffix that input files must share to be considered. Allows to exclude unwanted peak files.\n\
        Default = _peaks_annotated\n\n\
    ${BOLD}-F${END} ${UDL}extension${END}, ${BOLD}F${END}ormatInput\n\
        Define extension of files to use as input.\n\
        Default = 'bed'\n\n\

${BOLD}ARGUMENTS${END}\n\
        ${BOLD}<input_dir>${END}\n\
                Directory containing .fastq.gz or .fq.gz files to use as input for QC.\n\n\
        ${BOLD}<fasta_file>${END}\n\
                \n\n\
        ${BOLD}<gtf_file>${END}\n\
                \n\n\
        ${BOLD}<motif_file>${END}\n\
                \n\n\

${BOLD}EXAMPLE USAGE${END}\n\
        sh 9_WinPeaks.sh HOMER/Peaks /LAB-DATA/BiRD/users/jleger/Ref/Genome/Mus_musculus.GRCm39.dna_sm.primary_assembly.fa /LAB-DATA/BiRD/users/jleger/Ref/Genome/Mus_musculus.GRCm39.108.gtf /LAB-DATA/BiRD/users/jleger/Ref/Motifs/NFIL3_Known.motif\n"
}

################################################################################################################
### OPTIONS ----------------------------------------------------------------------------------------------------
################################################################################################################

# Set default values
N_arg="_peaks_annotated"
F_arg='bed'

# Change default values if another one is precised
while getopts ":N:F:" option; do
    case $option in
        N) # SUFFIX TO DISCRIMINATE FILES FOR INPUT
            N_arg=${OPTARG};;
        F) # FORMAT INPUT
            F_arg=${OPTARG};;
        \?) # Error
            echo "Error : invalid option"
            echo "      Allowed options are [-N|-F]"
            echo "      Enter sh WinPeaks.sh help for more details"
            exit;;
        esac
done

# Deal with options [-N] and arguments [$1|$2|...]
shift $((OPTIND-1))

################################################################################################################
### ERRORS -----------------------------------------------------------------------------------------------------
################################################################################################################

# Count .fastq.gz or .fq.gz files in provided directory
files=$(shopt -s nullglob dotglob; echo $1/*.fastq.gz $1/*.fq.gz)

if [ $# -eq 1 ] && [ $1 == "help" ]; then
        Help
        exit
elif [ $# -lt 3 ]; then
        # Error if inoccrect number of agruments is provided
        echo 'Error synthax : please use following synthax'
        echo '          sh WinPeaks.sh <input_dir> <fatsa_file> <gtf_file> <motif_file>'
        exit
fi

################################################################################################################
### SCRIPT -----------------------------------------------------------------------------------------------------
################################################################################################################

module load homer/4.11

# DNAse
# sh 9_WinPeaks.sh -N DNAse-seq_*_annotated HOMER/Peaks /SCRATCH-BIRD/users/jleger/Data/Ref/Genome/Mus_musculus.GRCm39.dna_sm.primary_assembly.fa /SCRATCH-BIRD/users/jleger/Data/Ref/Genome/Mus_musculus.GRCm39.108.gtf /SCRATCH-BIRD/users/jleger/Data/Ref/Motifs/NFIL3_Known.motif

# ChIC
# sh 9_WinPeaks.sh HOMER/Peaks /SCRATCH-BIRD/users/jleger/Data/Ref/Genome/Mus_musculus.GRCm39.dna_sm.primary_assembly.fa /SCRATCH-BIRD/users/jleger/Data/Ref/Genome/Mus_musculus.GRCm39.108.gtf ../NFIL3.motif 

motif=`echo ${4} | sed -e 's@\.motif@@g' | sed -e 's@.*\/@@g'` 

for current_tag in ${1}/*; do
    # Precise to eliminate empty lists for the loop
    shopt -s nullglob
    for i in "${current_tag}"/*${N_arg}*.${F_arg}; do
        # Set variables for jobname
        current_file=`echo "${i}" | sed -e "s@.*\/@@g" | sed -e "s@\.${F_arg}@@g"`
        # Launch annotation as a qsub
        echo -e "#$ -V \n#$ -cwd \n#$ -S /bin/bash \n\
        annotatePeaks.pl ${i} $2 -gtf $3 -m $4 > ${current_tag}/${current_file}_${motif}_location.txt" | qsub -N WinPeaks_"${current_file}"_"${motif}"
    done
done


