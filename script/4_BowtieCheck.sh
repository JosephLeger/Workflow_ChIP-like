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
	sh ${script_name} [options] <input_dir>\n\n\

${BOLD}DESCRIPTION${END}\n\
	Perform identification of duplicated and low quality reads in sorted BAM files and remove them using Picard.\n\
	It generates '_Duplist_<filename>.txt' which contains duplicates list and '<filename>_unique_filtered.bam' files.\n\n\

${BOLD}OPTIONS${END}\n\
	${BOLD}-N${END} ${UDL}suffix${END}, ${BOLD}N${END}amePattern\n\
		Define a suffix that input files must share to be considered. Allows to exclude BAM files that are unfiltered or unwanted.\n\
		Default = '_sorted'\n\n\
	${BOLD}-T${END} ${UDL}threshold${END}, ${BOLD}T${END}hresholdQuality\n\
		Define quality threshold for read filtering.\n\
		Default = 10\n\n\
	${BOLD}-R${END} ${UDL}boolean${END}, ${BOLD}R${END}emoveDuplicates\n\
		Whether remove duplicated reads or not.\n\
		Default = False\n\n\

${BOLD}ARGUMENTS${END}\n\
	${BOLD}<input_dir>${END}\n\
		Directory containing .bam files to process.\n\
		It usually corresponds to 'Mapped/<model>/BAM'.\n\n\

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
while getopts ":N:T:R:" option; do
	case $option in
		N) # NAME OF FILES (SUFFIX)
			N_arg=${OPTARG};;
 		T) # THRESHOLD FOR FILTERING
			T_arg=${OPTARG};;
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

# Deal with options [-N|-T|-R] and argument [$1]
shift $((OPTIND-1))

################################################################################################################
### ERRORS -----------------------------------------------------------------------------------------------------
################################################################################################################

if [ $# -eq 1 ] && [ $1 == "help" ]; then
	Help
	exit
elif [ $# -lt 1 ]; then
	# Error if inoccrect number of agruments is provided
	echo "Error synthax : please use following synthax"
	echo "      sh ${script_name} [options] <input_dir> <...>"
	exit
elif [ $(ls $1/*${N_arg}*.bam 2>/dev/null | wc -l) -lt 1 ]; then
	# Error if provided directory is empty or does not exists
	echo -e "Error : can not find files to filter in ${input} directory. Please make sure the provided input directory exists, and contains sorted .bam files."
	exit
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

# Precise to eliminate empty lists for the loop
shopt -s nullglob
# For each BAM file in provided directory
for file in ${1}/*${N_arg}*.bam; do
	# Set variables for the run :
	model=`echo ${1} | sed -e 's@.*Mapped\/@@g' | sed -e 's@\/.*@@g'`
	current_file=`echo ${file} | sed -e "s@${1}\/@@" | sed -e 's@\.bam@@g'`
	# Define JOBNAME and COMMAND and launch job
	if [ ${R_arg} == 'true' ]; then
		JOBNAME="BowtieCheck_${model}_${current_file}"
		COMMAND="picard MarkDuplicates INPUT=${i} \
		OUTPUT=${1}/${current_file}_unique.bam \
		VALIDATION_STRINGENCY=LENIENT \
		TMP_DIR=/tmp \
		METRICS_FILE=${1}/_DupList_${current_file}.txt \
 		REMOVE_DUPLICATES=true \n\
		samtools view -h ${1}/${current_file}_unique.bam | samtools view -b -Sq ${T_arg} > ${1}/${current_file}_unique_filtered.bam \n\
		samtools index ${1}/${current_file}_unique_filtered.bam ${1}/${current_file}_unique_filtered.bai"
		Launch 
	else 
		JOBNAME="BowtieCheck_${model}_${current_file}"
		COMMAND="samtools view -h ${file} | samtools view -b -Sq ${T_arg} > ${1}/${current_file}_filtered.bam \n\
		samtools index ${1}/${current_file}_filtered.bam ${1}/${current_file}_filtered.bai"
		Launch
	fi
done
          
