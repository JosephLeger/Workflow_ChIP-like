#!/bin/env bash

################################################################################################################
### HELP -------------------------------------------------------------------------------------------------------
################################################################################################################
script_name='mergeBAM.sh'

# Get user id for custom manual pathways
usr=`id | sed -e 's@).*@@g' | sed -e 's@.*(@@g'`

# Text font variables
END='\033[0m'
BOLD='\033[1m'
UDL='\033[4m'

# Show command manual
Help()
{
echo -e "${BOLD}####### MERGEBAM MANUAL #######${END}\n\n\
${BOLD}SYNTHAX${END}\n\
	sh ${script_name} [options] <input_dir> <sheet_sample.csv>\n\n\

${BOLD}DESCRIPTION${END}\n\
	Merge BAM files matching a pattern into a unique BAM file and index it using samtools.\n\
	Can be used before calling peaks on an accumulation of experiments to have higher signals.\n\
	It requires sample information in a provided .csv file (see example_sheet_sample.csv).\n\n\

${BOLD}OPTIONS${END}\n\
	${BOLD}-N${END} ${UDL}suffix${END}, ${BOLD}N${END}amePattern\n\
		Define a suffix that input files must share to be considered. Allows to exclude BAM files that are unwanted.\n\
		Default = '_filtered'\n\n\
	${BOLD}-R${END} ${UDL}boolean${END}, ${BOLD}R${END}emoveSuffix\n\
		Specify whether provided suffix from input filename have to be removed in output filename.\n\
		Default = false\n\n\

${BOLD}ARGUMENTS${END}\n\
	${BOLD}<input_dir>${END}\n\
		Directory containing .bam files to process.\n\
		It usually corresponds to 'Mapped/<model>/BAM'.\n\n\
	${BOLD}<sheet_sample.csv>${END}\n\
		Path to .csv files containing sample information stored in 3 columns : 
  			1) File_ID (unique patterns to identify files)
     			2) Info (sample description, not used by the script)
			3) Condition (files sharing the same Condition will be merged together)\n\n\
   		
${BOLD}EXAMPLE USAGE${END}\n\
	sh ${script_name} ${BOLD}-N${END} _sorted_filtered ${BOLD}-R${END} true ${BOLD}Mapped/mm39/BAM ../SRA_SampleLists.csv${END}\n"
}

################################################################################################################
### OPTIONS ----------------------------------------------------------------------------------------------------
################################################################################################################

# Set default values
N_arg='_filtered'
R_arg='false'

# Change default values if another one is precised
while getopts ":N:R:" option; do
	case $option in
		N) # NAME OF FILE (SUFFIX)
			N_arg=${OPTARG};;
		R) # REMOVE SUFFIX IN OUTPUT FILENAME
			R_arg=${OPTARG};;
		\?) # Error
			echo "Error : invalid option"
			echo "      Allowed options are [-N|-R]"
			echo "      Enter 'sh ${script_name} help' for more details"
			exit;;
	esac
done

# Checking if provided option values are correct
case $R_arg in
	true|TRUE|True|T) 
		newsuffix='_merged.bam';;
	false|FALSE|False|F)
		newsuffix=${N_arg}'_merged.bam';;
	*) 
		echo "Error value : -R argument must be 'true' or 'false'"
		exit;;
esac
# Deal with options [-N|-R] and arguments [$1|$2|...]
shift $((OPTIND-1))

################################################################################################################
### ERRORS -----------------------------------------------------------------------------------------------------
################################################################################################################

if [ $# -eq 1 ] && [ $1 == "help" ]; then
	Help
	exit
elif [ $# -ne 2 ]; then
	# Error if arguments are missing
	echo "Error synthax : please use following synthax"
	echo "      sh ${script_name} <input_dir> <data_sheet.csv>"
	exit
elif [ $(ls $1/*${N_arg}*.bam 2>/dev/null | wc -l) -lt 1 ]; then
	# Error if provided directory is empty or does not exists
	echo "Error : can not find files to merge in ${input} directory. Please make sure the provided input directory exists, and contains correct .bam files."
	exit
fi

################################################################################################################
### SCRIPT -----------------------------------------------------------------------------------------------------
################################################################################################################


## SETUP - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
module load samtools/1.15.1

# Generate REPORT
echo '#' >> ./0K_REPORT.txt
date >> ./0K_REPORT.txt

Launch()
{
# Launch COMMAND and save report
echo -e "#$ -V \n#$ -cwd \n#$ -S /bin/bash \n"${COMMAND} | qsub -N ${JOBNAME} ${WAIT}
echo -e ${JOBNAME} >> ./0K_REPORT.txt
echo -e ${COMMAND} | sed 's@^@   \| @' >> ./0K_REPORT.txt
}
WAIT=''

## MERGE BAM - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 
# Establish conditions_list which contains already visited condition
conditions_list=""
sed 1d ${2} | while IFS=',' read -r id info condition; do
	# Read the entire sheet condition columns
	condition=$(echo $condition | tr -d '\r')
	# Check if current $condition is already written in $conditions_list
	is_present=`echo $conditions_list | grep -ce $condition`

	# If $condition is not written yet in $conditions_list
	if [ $is_present -eq 0 ]; then
		# Add it to the list to not visiting it again
		conditions_list="${conditions_list} ${condition}"
		
		# Initialize $list_files to store filenames to merge
		list_files=""
		# Look for $id in the entire sheet that share current $condition
		sed 1d ${2} | (while IFS=',' read -r id_sub info_sub condition_sub; do
			id=$(echo $id | tr -d '\r')
			condition_sub=$(echo $condition_sub | tr -d '\r')
			if [ "$condition_sub" == "$condition" ]; then
				# Search for $files correspoinding to current matching $id
				newfile=`find ${1} -type f -iname "*${id_sub}*${N_arg}*.bam"`
				list_files="${list_files} ${newfile}"
			fi
		done
		# Define JOBNAME and COMMAND and launch job
		JOBNAME="mergeBAM_${condition}"
		COMMAND="samtools merge -o ${1}/${condition}${newsuffix} ${list_files} \n\
		samtools index ${1}/${condition}${newsuffix}"
		Launch)        
	fi
done