#!/bin/env bash

################################################################################################################
### HELP -------------------------------------------------------------------------------------------------------
################################################################################################################
script_name='indexBAM.sh'

# Get user id for custom manual pathways
usr=`id | sed -e 's@).*@@g' | sed -e 's@.*(@@g'`

# Text font variables
END='\033[0m'
BOLD='\033[1m'
UDL='\033[4m'

# Show command manual
Help()
{
echo -e "${BOLD}####### INDEXBAM MANUAL #######${END}\n\n\
${BOLD}SYNTHAX${END}\n\
	sh ${script_name} [options] <input_dir>\n\n\

${BOLD}DESCRIPTION${END}\n\
	Index soretd BAM files using samtools.\n\
	If BAM files are not sorted, it is possible to sort them using Picard.\n\n\

${BOLD}OPTIONS${END}\n\
	${BOLD}-N${END} ${UDL}suffix${END}, ${BOLD}N${END}amePattern\n\
		Define a suffix that input files must share to be considered. Allows to exclude BAM files that are unwanted.\n\
		Default = ''\n\n\
	${BOLD}-S${END} ${UDL}boolean${END}, ${BOLD}S${END}ortBAM\n\
		Define whether BAM files have to be sorted using Picard prior indexing.\n\
		Default = false\n\n\

${BOLD}ARGUMENTS${END}\n\
	${BOLD}<input_dir>${END}\n\
		Directory containing BAM files to index.\n\n\
   		
${BOLD}EXAMPLE USAGE${END}\n\
	sh ${script_name} ${BOLD}-N${END} _sorted ${BOLD}-S${END} true ${BOLD}./BAM_directory${END}\n"
}

################################################################################################################
### OPTIONS ----------------------------------------------------------------------------------------------------
################################################################################################################

# Set default values
N_arg=''
S_arg='false'

# Change default values if another one is precised
while getopts ":N:S:" option; do
	case $option in
		N) # NAME OF FILE (SUFFIX)
			N_arg=${OPTARG};;
		S) # SORT FILE
			S_arg=${OPTARG};;
		\?) # Error
			echo "Error : invalid option"
			echo "      Allowed options are [-N]"
			echo "      Enter 'sh ${script_name} help' for more details"
			exit;;
	esac
done

# Checking if provided option values are correct
case $S_arg in
	TRUE|True|true|T|t) 
		S_arg='true'
		newsuffix='_sorted';;
	FALSE|False|false|F|f) 
		S_arg='false'
		newsuffix='';;
	*) 
		echo "Error value : -S argument must be 'true' or 'false'"
		exit;;
esac

# Deal with options [-M|-S] and arguments [$1|$2|...]
shift $((OPTIND-1))

################################################################################################################
### ERRORS -----------------------------------------------------------------------------------------------------
################################################################################################################

if [ $# -eq 1 ] && [ $1 == "help" ]; then
	Help
	exit
elif [ $# -ne 1 ]; then
	# Error if arguments are missing
	echo "Error synthax : please use following synthax"
	echo "      sh ${script_name} <input_dir>"
	exit
elif [ $(ls $1/*${N_arg}*.bam 2>/dev/null | wc -l) -lt 1 ]; then
	# Error if provided directory is empty or does not exists
	echo "Error : can not find files in ${input} directory. Please make sure the provided input directory exists, and contains correct .bam files."
	exit
fi

################################################################################################################
### SCRIPT -----------------------------------------------------------------------------------------------------
################################################################################################################

## SETUP - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Generate REPORT
echo '#' >> ./0K_REPORT.txt
date >> ./0K_REPORT.txt

Launch()
{
# Launch COMMAND while getting JOBID
JOBID=$(echo -e "#!/bin/bash \n\
#SBATCH --job-name=${JOBNAME} \n\
#SBATCH --output=%x_%j.out \n\
#SBATCH --error=%x_%j.err \n\
#SBATCH --time=${TIME} \n\
#SBATCH --nodes=${NODE} \n\
#SBATCH --ntasks=${TASK} \n\
#SBATCH --cpus-per-task=${CPU} \n\
#SBATCH --mem=${MEM} \n\
#SBATCH --qos=${QOS} \n\
source /home/${usr}/.bashrc \n\
micromamba activate Workflow_ChIP-like \n""${COMMAND}" | sbatch --parsable --clusters nautilus ${WAIT})
# Define JOBID and print launching message
JOBID=`echo ${JOBID} | sed -e "s@;.*@@g"` 
echo "Submitted batch job ${JOBID} on cluster nautilus"
# Fill in 0K_REPORT file
echo -e "${JOBNAME}_${JOBID}" >> ./0K_REPORT.txt
echo -e "${COMMAND}" | sed 's@^@   \| @' >> ./0K_REPORT.txt
}
# Define default waiting list for sbatch as empty
WAIT=''

## SORT BAM - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 
# Set up parameters for SLURM ressources
TIME='0-00:30:00'; NODE='1'; TASK='1'; CPU='1'; MEM='2g'; QOS='quick'

# Precise to eliminate empty lists for the loop
shopt -s nullglob
# Sort each provided file
for file in ${1}/*${N_arg}*.bam; do
	# Set variables for jobname
	current_file=`echo ${file} | sed -e "s@${1}\/@@g" | sed -e 's@\.bam@@g'`
	# Define JOBNAME and COMMAND and launch job while append JOBLIST
	JOBNAME="indexBAM_${current_file}"
	if [ ${S_arg} == 'true' ]; then
		COMMAND="samtools sort ${file} -o ${1}/${current_file}_sorted.bam \n\
		samtools index ${1}/${current_file}_sorted.bam"
	else
		COMMAND="samtools index ${file}"
	fi
	Launch
done
