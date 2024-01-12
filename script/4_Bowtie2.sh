#!bin/env bash

################################################################################################################
### HELP -------------------------------------------------------------------------------------------------------
################################################################################################################
script_name='4_Bowtie2.sh'

# Get user id for custom manual pathways
usr=`id | sed -e 's@).*@@g' | sed -e 's@.*(@@g'`

# Text font variables
END='\033[0m'
BOLD='\033[1m'
UDL='\033[4m'

# Show command manual
Help()
{
echo -e "${BOLD}####### BOWTIE2 MANUAL #######${END}\n\n\
${BOLD}SYNTHAX${END}\n\
    sh ${script_name} [options] <SE|PE> <input_dir> <refindex>\n\n\

${BOLD}DESCRIPTION${END}\n\
    Perform alignement on genome reference from paired or unpaired fastq files using Bowtie2.\n\
    It creates new folders './Mapped/<model>/SAM' and './Mapped/<model>/BAM' in which resulting aligned files are stored.\n\
    Generated BAM files are automatically sorted using picard for following steps.\n\n\

${BOLD}OPTIONS${END}\n\
    ${BOLD}-U${END} ${UDL}boolean${END}, ${BOLD}U${END}nalignedReadsRemovam\n\
        Whether remove unaligned reads to output file. \n\
        Default = 'False'\n\n\
    ${BOLD}-L${END} ${UDL}boolean${END}, ${BOLD}L${END}ocalAlignment\n\
        Whether use Local alignment instead of global.\n\
        Default = 'False'\n\n\
    ${BOLD}-N${END} ${UDL}integer${END}, ${BOLD}N${END}umberOfMismatch\n\
        Maximum number of mismatch allowed while perform alignment. \n\
        Default = 0\n\n\

${BOLD}ARGUMENTS${END}\n\
    ${BOLD}<SE|PE>${END}\n\
        Define whether fastq files are Single-End (SE) or Paired-End (PE).\n\
        If SE is provided, each file is aligned individually and give rise to an output file stored in './Mapped/<model>/SAM' directory.\n\
        If PE is provided, files are aligned in pair (R1 and R2), giving rise to a single output file from a pair of input files.\n\n\
    ${BOLD}<input_dir>${END}\n\
        Directory containing .fastq.gz or .fq.gz files to use as input for alignment.\n\
        It usually corresponds to 'Raw' or 'Trimmed/Trimmomatic'.\n\n\
    ${BOLD}<refindex>${END}\n\
        Path to reference previously indexed using bowtie2-build.\n\
        Provided path must be ended by reference name (prefix common to files).\n\n\
        
${BOLD}EXAMPLE USAGE${END}\n\
    ${BOLD}sh ${script_name} PE Trimmed/Trimmomatic/Paired /LAB-DATA/BiRD/users/${usr}/Ref/refdata-Bowtie2-mm39/mm39${END}\n"
}

################################################################################################################
### OPTIONS ----------------------------------------------------------------------------------------------------
################################################################################################################

# Set default values
U_arg='false'
L_arg='false'
N_arg=0

# Change default values if another one is precised
while getopts ":U:S:L:T:M:I:" option; do
    case $option in
        U) # UNALIGNED
            U_arg=${OPTARG};;
        L) # LOCAL
            L_arg=${OPTARG};;
        N) # NUMBER OF ALLOWED MISSMATCH
            N_arg=${OPTARG};;
        \?) # Error
            echo "Error : invalid option"
            echo "      Allowed options are [-U|-L|-N]"
            echo "      Enter 'sh ${script_name} help' for more details"
            exit;;
    esac
done

# Checking if provided option values are correct
case $U_arg in
    TRUE|True|true|T|t) 
        U_arg='--no-unal';;
    FALSE|False|false|F|f) 
        U_arg='';;
    *) 
        echo "Error value : -U argument must be 'true' or 'false'"
        exit;;
esac
case $L_arg in
    TRUE|True|true|T|t) 
        L_arg='--local';;
    FALSE|False|false|F|f) 
        L_arg='';;
    *) 
        echo "Error value : -L argument must be 'true' or 'false'"
        exit;;
esac

# Deal with options [-U|-L|-N] and arguments [$1|$2]
shift $((OPTIND-1))

################################################################################################################
### ERRORS -----------------------------------------------------------------------------------------------------
################################################################################################################

# Count .fastq.gz pr .fq.gz files in provided directory
files=$(shopt -s nullglob dotglob; echo $2/*.fastq.gz $2/*.fq.gz)

if [ $# -eq 1 ] && [ $1 == "help" ]; then
    Help
    exit
elif [ $# -lt 3 ]; then
    # Error if no directory is provided
    echo "Error synthax : please use following synthax"
    echo "      sh ${script_name} <SE|PE> <input_dir> <refindex>"
    exit
elif (( !${#files} )); then
    # Error if provided directory is empty or does not exists
    echo -e "Error : can not find files in $2 directory. Please make sure the provided directory exists, and contains .fastq.gz or .fq.gz files."
    exit
else
    # Error if the correct number of arguments is provided but the first does not match 'SE' or 'PE'
    case $1 in
        PE|SE) 
            ;;
        *) 
            echo "Error Synthax : please use following synthax"
            echo "       sh ${script_name} <SE|PE> <input_dir> <refindex>"
            exit;;
    esac
fi

################################################################################################################
### SCRIPT -----------------------------------------------------------------------------------------------------
################################################################################################################

module load bowtie2/2.5.1
module load samtools/1.15.1
module load picard/2.23.5

# Create output directories
model=`echo $3 | sed -r 's/^.*\/(.*)$/\1/'`
mkdir -p ./Mapped/${model}/SAM
mkdir -p ./Mapped/${model}/BAM

if [ $1 == "SE" ]; then
    # Precise to eliminate empty lists for the loop
    shopt -s nullglob
    # For each read file
    for i in $2/*.fq.gz $2/*.fastq.gz; do
        # Set variables for jobname
        current_file=`echo $i | sed -e "s@${2}\/@@g" | sed -e 's@\.fastq\.gz\|\.fq\.gz@@g'`

        # Launch alignment to experiment model refseq as qsub
        echo -e "#$ -V \n#$ -cwd \n#$ -S /bin/bash \n\
        bowtie2 -p 2 -N ${N_arg} ${L_arg} ${U_arg}\
        -x $3 \
        -U $i \
        -S Mapped/${model}/SAM/${current_file}.sam \n\
        picard SortSam \
        INPUT=Mapped/${model}/SAM/${current_file}.sam \
        OUTPUT=Mapped/${model}/BAM/${current_file}_sorted.bam \
        VALIDATION_STRINGENCY=LENIENT \
        TMP_DIR=tmp \
        SORT_ORDER=coordinate" | qsub -N Bowtie2_${1}_${model}_${current_file}
    done

elif [ $1 == "PE" ]; then
    # Precise to eliminate empty lists for the loop
    shopt -s nullglob
    # If PE (Paired-End) is selected, each paired files are aligned together
    for i in $2/*_R1*.fastq.gz $2/*_R1*.fq.gz; do
        # Set variables for jobname
        current_pair=`echo $i | sed -e "s@${2}\/@@g" | sed -e 's/_R1//g' | sed -e 's@\.fastq\.gz\|\.fq\.gz@@g'`
        # Define paired files
        R1=$i
        R2=`echo $i | sed -e 's/_R1/_R2/g'`
        # Launch alignment to experiment model refseq as qsub
        echo -e "#$ -V \n#$ -cwd \n#$ -S /bin/bash \n\
        bowtie2 -p 2 -q -N ${N_arg} ${L_arg} ${U_arg} \
        -x $3 \
        -1 ${R1} \
        -2 ${R2} \
        -S Mapped/${model}/SAM/${current_pair}.sam
        picard SortSam \
        INPUT=Mapped/${model}/SAM/${current_pair}.sam \
        OUTPUT=Mapped/${model}/BAM/${current_pair}_sorted.bam \
        VALIDATION_STRINGENCY=LENIENT \
        TMP_DIR=tmp \
        SORT_ORDER=coordinate" | qsub -N Bowtie2_${1}_${model}_${current_pair}
    done

fi
