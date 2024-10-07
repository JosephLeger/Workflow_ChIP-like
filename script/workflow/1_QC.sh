#!/bin/env bash

################################################################################################################
### HELP -------------------------------------------------------------------------------------------------------
################################################################################################################
script_name='1_QC.sh'

# Get user id for custom manual pathways
usr=`id | sed -e 's@).*@@g' | sed -e 's@.*(@@g'`

# Text font variables
END='\033[0m'
BOLD='\033[1m'
UDL='\033[4m'

# Show command manual
Help()
{
echo -e "${BOLD}####### QC MANUAL #######${END}\n\n\
${BOLD}SYNTHAX${END}\n\
	sh ${script_name} <input_dir>\n\n\

${BOLD}DESCRIPTION${END}\n\
	Generate summarized quality check report for raw, trimmed or mapped files using MultiQC.\n\
 	If FASTQ files are provided, first launch FastQC to generate individual quality reports.\n\
	It creates new folders './QC/<input_dir>' and './QC/MultiQC' in which quality check results are stored.\n\
	Output files are HTML files for direct visualization and ZIP files containing results.\n\n\

${BOLD}ARGUMENTS${END}\n\
	${BOLD}<input_dir1>${END}\n\
		Directory containing QC reports files or FASTQ files.\n\n\
  		Usually corresponds to 'Raw', 'Trimmed', 'STAR' or 'RSEM'.
		
${BOLD}EXAMPLE USAGE${END}\n\
	sh ${script_name} ${BOLD}Raw${END}\n"
}

################################################################################################################
### ERRORS -----------------------------------------------------------------------------------------------------
################################################################################################################

if [ $# -eq 1 ] && [ $1 == "help" ]; then
	Help
	exit
elif [ $# -ne 1 ]; then
  # Error if inoccrect number of agruments is provided
	echo "Error synthax : please use following synthax"
	echo "          sh ${script_name} <input_dir>"
	exit
elif [ $(ls $1/*.fastq.gz $1/*.fq.gz $1/**/*.cnt $1/*.out 2>/dev/null | wc -l) -lt 1 ]; then		
	# Error if provided directories are empty or don't exist
 	echo -e "Error : can not find any file in provided directories. Please make sure the provided input directories exist, and contain .fastq.gz or .fq.gz files."
	exit
fi

################################################################################################################
### SCRIPT -----------------------------------------------------------------------------------------------------
################################################################################################################

## SETUP - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
module load fastqc/0.11.9
module load multiqc/1.13

# Generate REPORT
echo '#' >> ./0K_REPORT.txt
date >> ./0K_REPORT.txt

Launch()
{
# Launch COMMAND and save report
echo -e "#$ -V \n#$ -cwd \n#$ -S /bin/bash \n""${COMMAND}" | qsub -N "${JOBNAME}" ${WAIT}
echo -e "${JOBNAME}" >> ./0K_REPORT.txt
echo -e "${COMMAND}" | sed 's@^@   \| @' >> ./0K_REPORT.txt
}
WAIT=''

## FASTQC - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 
if [ $(ls $1/*.fastq.gz $1/*.fq.gz 2>/dev/null | wc -l) -gt 0 ]; then
	# Initialize JOBLIST to wait before running MultiQC
	JOBLIST='_'
	# Create directory in QC folder following the same path than input path provided
	outdir=QC/$1
	mkdir -p ${outdir}
	# Generate jobname replacing '/' by '_'
	name=`echo $1 | sed -e 's@\/@_@g'`
	# Precise to eliminate empty lists for the loop
	shopt -s nullglob
	# Launch FastQC for each provided file
	for i in $1/*.fastq.gz $1/*.fq.gz; do
		# Set variables for jobname
		current_file=`echo $i | sed -e "s@$1\/@@g" | sed -e "s@\.fastq\.gz\|\.fq\.gz@@g"`
		# Define JOBNAME and COMMAND and launch job while append JOBLIST
		JOBNAME="QC_${name}_${current_file}"
		COMMAND="fastqc -o ${outdir} --noextract -f fastq $i"
		JOBLIST=${JOBLIST}','${JOBNAME}
		Launch
	done
 	WAIT=`echo ${JOBLIST} | sed -e 's@_,@-hold_jid @'`
else
	outdir=$1
fi

## MULTIQC - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Create directory in QC folder for MultiQC
outdir2='./QC/MultiQC'
mkdir -p ${outdir2}
# Create output name without strating 'QC/' and replacing '/' by '_'
name=`echo ${outdir} | sed -e 's@\/@_@g'`

# Define JOBNAME, COMMAND and launch with WAIT list
JOBNAME="MultiQC_${name}"
COMMAND="multiqc ${outdir} -o ${outdir2} -n ${name}_MultiQC"
Launch
