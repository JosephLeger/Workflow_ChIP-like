#!/bin/env bash

################################################################################################################
### HELP -------------------------------------------------------------------------------------------------------
################################################################################################################
script_name='4_BowtieCheck.sh'

# Get user id for custom manual pathways
usr=`id | sed -e 's@).*@@g' | sed -e 's@.*(@@g'`

# Text font variables
END='\033[0m'
BOLD='\033[1m'
UDL='\033[4m'

# Show command manual
Help()
{
echo -e "${BOLD}####### FILTER MANUAL #######${END}\n\n\
${BOLD}SYNTHAX${END}\n\
    sh ${script_name} [options] <input_dir1> <...>\n\n\

${BOLD}DESCRIPTION${END}\n\
    Perform identification of duplicated and low quality reads in sorted BAM files and remove them.\n\
    It generates '_Duplist_<filename>.txt' which contains duplicates list and '<filename>_unique_filtered.bam' files.\n\n\

${BOLD}OPTIONS${END}\n\
    ${BOLD}-N${END} ${UDL}suffix${END}, ${BOLD}N${END}amePattern\n\
        Define a suffix that input files must share to be considered. Allows to exclude BAM files that are unfiltered or unwanted.\n\
        Default = '_sorted'\n\n\
    ${BOLD}-T${END} ${UDL}threshold${END}, ${BOLD}T${END}hresholdQuality\n\
        Define quality threshold for read filtering.\n\
        Default = 10\n\n\
    ${BOLD}-R${END} ${UDL}boolean${END}, ${BOLD}R${END}emoveDuplicates\n\
        Whether remove duplicated or not.\n\
        Default = False\n\n\

${BOLD}ARGUMENTS${END}\n\
    ${BOLD}<input_dir>${END}\n\
        Directory containing .bam files to process.\n\
        It usually corresponds to 'Mapped/<model>/BAM'.\n\n\

    ${BOLD}<...>${END}\n\
        Several directories can be specified as argument in the same command line, allowing processing of multiple models simultaneously.\n\n\  

${BOLD}EXAMPLE USAGE${END}\n\
    sh ${script_name} ${BOLD}-N${END} _sorted ${BOLD}-T${END} 10 ${BOLD}-R${END} False ${BOLD}Mapped/mm39/BAM${END}\n"
}

################################################################################################################
### OPTIONS ----------------------------------------------------------------------------------------------------
################################################################################################################

# Set default values
N_arg='_sorted'
T_arg=10
R_arg='False'

# Change default values if another one is precised
while getopts ":T:N:R:" option; do
    case $option in
        T) # THRESHOLD FOR FILTERING
            T_arg=${OPTARG};;
        N) # NAME OF FILES (SUFFIX)
            N_arg=${OPTARG};;
        R) # REMOVE DUPLICATES
            R_arg=${OPTARG};;
        \?) # Error
            echo "Error : invalid option"
            echo "      Allowed options are [-N|-T|-R]"
            echo "      Enter 'sh ${script_name} help' for more details"
            exit;;
        esac
done

# Checking if provided option values are correct
case $T_arg in
    None|none|False|F|FALSE|false) 
        T_arg="none";;
    *) 
        T_arg=$T_arg;;
esac
case $R_arg in
    False|F|FALSE|false) 
        R_arg='false';;
    True|T|TRUE|true)
        R_arg='true';;
    *) 
        echo "Error value : -R argument must be 'true' or 'false'"
        exit;;
esac

# Deal with options [-N|-T|-R] and arguments [$1|$2|...]
shift $((OPTIND-1))

################################################################################################################
### ERRORS ----------------------------------------------------------------------------------------------------''
################################################################################################################

if [ $# -eq 1 ] && [ $1 == "help" ]; then
        Help
        exit
elif [ $# == 0 ]; then
        # Error if inoccrect number of agruments is provided
        echo "Error synthax : please use following synthax"
        echo "      sh ${script_name} [options] <input_dir1> <...>"
        exit
else
    # For each input file given as argument
    for input in "$@"; do
        # Count .bam files matching -N pattern in provided directory
        files=$(shopt -s nullglob dotglob; echo ${input}/*${N_arg}*.bam)
        if (( !${#files} )); then
            # Error if current provided directory is empty or does not exists
            echo -e "Error : can not find files to filter in ${input} directory. Please make sure the provided input directory exists, and contains sorted .bam files."
            exit
        fi
    done
fi

################################################################################################################
### SCRIPT -----------------------------------------------------------------------------------------------------
################################################################################################################

## SETUP - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
module load samtools/1.15.1
module load picard/2.23.5

# Generate REPORT
echo '#' >> ./0K_REPORT.txt
date >> ./0K_REPORT.txt

Launch()
{
# Launch COMMAND and save report
echo -e "#$ -V \n#$ -cwd \n#$ -S /bin/bash \n"${COMMAND} | qsub -N ${JOBNAME} ${WAIT}
echo -e ${JOBNAME} >> ./0K_REPORT.txt
echo -e ${COMMAND} | sed -r 's@\|@\n@g' | sed 's@^@   \| @' >> ./0K_REPORT.txt
}
WAIT=''

## BOWTIE CHECK - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 
# For each input file given as argument
for input in "$@"; do   
    # Precise to eliminate empty lists for the loop
    shopt -s nullglob
    for i in ${input}/*${N_arg}*.bam; do
        # Set variables for the run :
        model=`echo ${input} | sed -e 's@.*Mapped\/@@g' | sed -e 's@\/.*@@g'`
        current_file=`echo $i | sed -e "s@${input}\/@@" | sed -e 's@\.bam@@g'`
        # Define JOBNAME and COMMAND and launch job
        if [ ${R_arg} == 'true' ]; then
            JOBNAME="BowtieCheck_${model}_${current_file}"
            COMMAND="picard MarkDuplicates INPUT=${i} \
            OUTPUT=${input}/${current_file}_unique.bam \
            VALIDATION_STRINGENCY=LENIENT \
            TMP_DIR=/tmp \
            METRICS_FILE=${input}/_DupList_${current_file}.txt \
            REMOVE_DUPLICATES=true \n\
            samtools view -h ${input}/${current_file}_unique.bam | samtools view -b -Sq ${T_arg} > ${input}/${current_file}_unique_filtered.bam \n\
            samtools index ${input}/${current_file}_unique_filtered.bam ${input}/${current_file}_unique_filtered.bai"
            Launch 
        else 
            JOBNAME="BowtieCheck_${model}_${current_file}"
            COMMAND="samtools view -h ${i} | samtools view -b -Sq ${T_arg} > ${input}/${current_file}_filtered.bam \n\
            samtools index ${input}/${current_file}_filtered.bam ${input}/${current_file}_filtered.bai"
            Launch
        fi
    done
done
          
