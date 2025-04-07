#!/bin/env bash

################################################################################################################
### HELP -------------------------------------------------------------------------------------------------------
################################################################################################################
script_name='mergeFASTQ.sh'

# Get user id for custom manual pathways
usr=`id | sed -e 's@).*@@g' | sed -e 's@.*(@@g'`

# Text font variabes
END='\033[0m'
BOLD='\033[1m'
UDL='\033[4m'

# Show command manual
Help()
{
echo -e "${BOLD}####### MERGEFASTQ MANUAL #######${END}\n\n\
${BOLD}SYNTHAX${END}\n\
	sh mergeFastq.sh <input_dir> <file_table.csv>\n\n\
${BOLD}DESCRIPTION${END}\n\
\n\n\

${BOLD}ARGUMENTS${END}\n\
	${BOLD}<input_dir>${END}\n\
		Directory containing FASTQ files to merge.\n\
	${BOLD}<file_table.csv>${END}\n\
		Path to .csv file containing sample information stored in 3 columns : 
  			1) File_ID (unique patterns to identify raw files) 
     			2) Filename (used as filenames for merged files) 
			3) Condition [not used by this script]\n\n\

${BOLD}EXAMPLE USAGE${END}\n\
	sh ${script_name} Raw FileTable.csv\n"   
}

################################################################################################################
### ERRORS -----------------------------------------------------------------------------------------------------
################################################################################################################

if [ $# -eq 1 ] && [ $1 == "help" ]; then
	Help
	exit
elif [ $# -ne 2 ]; then
	# Error if inoccrect number of agruments is provided
	echo "Error synthax : please use following synthax"
	echo "      sh ${script_name} <input_dir> <sample_list>"
	exit
elif [ $(ls $1/*.fastq.gz $1/*.fq.gz 2>/dev/null | wc -l) -lt 1 ]; then
	# Error if provided directory is empty or does not exists
	echo -e "Error : can not find files in $1 directory. Please make sure the provided directory exists, and contains .fastq.gz or .fq.gz files."
	exit
fi

################################################################################################################
### SCRIPT -----------------------------------------------------------------------------------------------------
################################################################################################################

## SETUP - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
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

## MERGE FASTQ - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Set up parameters for SLURM ressources
TIME='0-00:05:00'; NODE='1'; TASK='1'; CPU='8'; MEM='2g'; QOS='quick'

# Create new directory organization
outdir="${1}/Merged"
mkdir -p  ${outdir}

# Establish filename_list which contains already created new files
filename_list=""
sed 1d ${2} | while IFS=',' read -r id filename condition; do
	# Read the entire sheet filename columns
	filename=$(echo $filename | tr -d '\r')
	# Check if current $filename is already written in $filename_list
	is_present=`echo $filename_list | grep -ce $filename`
	
	# If $filename is not written yet in $filename_list
	if [ $is_present -eq 0 ]; then
		# Add it to the list to not visiting it again
		filename_list="${filename_list} ${filename}"
			
		# Initialize $list_files to store filenames to merge
		list_files=""
		# Look for $id in the entire sheet that share current $filename
		sed 1d ${2} | (while IFS=',' read -r id_sub filename_sub condition_sub; do
			id=$(echo $id | tr -d '\r')
			filename_sub=$(echo $filename_sub | tr -d '\r')
			if [ "$filename_sub" == "$filename" ]; then
				# Search for $files correspoinding to current matching $filename
				newfile=`find ${1} -type f -iname "*${id_sub}*.fastq.gz" -o -iname "*${id_sub}*.fq.gz"`
				list_files="${list_files} ${newfile}"
			fi
		done
		# Define JOBNAME and COMMAND and launch job
		JOBNAME="mergeFASTQ_${filename}"
		COMMAND="cat ${list_files} >> ${outdir}/${filename}.fastq.gz"
		Launch)        
	fi
done
