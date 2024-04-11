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
        sh ${script_name} <input_dir1> <...>\n\n\

${BOLD}DESCRIPTION${END}\n\
        Perform quality check of FASTQ files using FastQC and merge results into a single file using MultiQC.\n\
        It creates new folders './QC/<input_dir>' and './QC/MultiQC' in which quality check results are stored.\n\
        Output files are .html files for direct visualization and .zip files containing results.\n\n\

${BOLD}ARGUMENTS${END}\n\
        ${BOLD}<input_dir1>${END}\n\
                Directory containing .fastq.gz or .fq.gz files to use as input for QC.\n\n\
        ${BOLD}<...>${END}\n\
                Several directories can be specified as argument in the same command line.\n\n\
                
${BOLD}EXAMPLE USAGE${END}\n\
        sh ${script_name} ${BOLD}Raw${END}\n"
}

################################################################################################################
### ERRORS -----------------------------------------------------------------------------------------------------
################################################################################################################

# Count .fastq.gz or .fq.gz files in provided directory
files=$(shopt -s nullglob dotglob; echo $1/*.fastq.gz $1/*.fq.gz)

if [ $# -eq 1 ] && [ $1 == "help" ]; then
        Help
        exit
elif [ $# -lt 1 ]; then
        # Error if inoccrect number of agruments is provided
        echo "Error synthax : please use following synthax"
        echo "          sh ${script_name} <input_dir1> <...>"
        exit
else
        input_list=''
        # For each input file given as argument
        for input in "$@"; do
                # Precise to eliminate empty lists for the loop
                shopt -s nullglob
                for i in ${input}/*.fastq.gz ${input}/*.fq.gz; do
                        input_list=${input_list}${i}' '
                done
        done
        if (( !${#input_list} )); then
                # Error if current provided directories are all empty
                echo -e "Error : can not find any file in provided directories. Please make sure the provided input directories exist, and contain .fastq.gz or .fq.gz files."
                exit
        fi
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
echo -e "#$ -V \n#$ -cwd \n#$ -S /bin/bash \n"${COMMAND} | qsub -N ${JOBNAME} ${WAIT}
echo -e ${JOBNAME} >> ./0K_REPORT.txt
echo -e ${COMMAND} |  sed 's@^@   \| @' >> ./0K_REPORT.txt
}
WAIT=''

## FASTQC - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 
# Initialize JOBLIST to wait before running MultiQC
JOBLIST='_'

# For each input file given as argument
for input in "$@"; do
        # Create directory in QC folder following the same path than input path provided
        outdir=QC/${input}
        mkdir -p ${outdir}
        # Generate jobname replacing '/' by '_'
        name=`echo ${input} | sed -e 's@\/@_@g'`
        # Precise to eliminate empty lists for the loop
        shopt -s nullglob
        # Launch FastQC for each provided file
        for i in ${input}/*.fastq.gz ${input}/*.fq.gz; do
                # Set variables for jobname
                current_file=`echo $i | sed -e "s@${input}\/@@g" | sed -e "s@\.fastq\.gz\|\.fq\.gz@@g"`
                # Define JOBNAME and COMMAND and launch job while append JOBLIST
                JOBNAME="QC_${name}_${current_file}"
                COMMAND="fastqc -o ${outdir} --noextract -f fastq $i"
		JOBLIST=${JOBLIST}','${JOBNAME}
                Launch
        done
done

## MULTIQC - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Create directory in QC folder for MultiQC
outdir2='./QC/MultiQC'
mkdir -p ${outdir2}
# Create output name without strating 'QC/' and replacing '/' by '_'
name=`echo ${outdir} | sed -e 's@\/@_@g'`

## Define JOBNAME, COMMAND and launch with WAIT list
JOBNAME="MultiQC_${name}"
COMMAND="multiqc ${outdir} -o ${outdir2} -n ${name}_MultiQC"
WAIT=`echo ${JOBLIST} | sed -e 's@_,@-hold_jid @'`
Launch
