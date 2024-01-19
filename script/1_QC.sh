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
        Perform quality check of FASTQ files using FastQC.\n\
        It creates a new folder './QC/<input_dir>' in which quality check results are stored.\n\
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

module load fastqc/0.11.9


# Generate REPORT
echo '#' >> ./0K_REPORT.txt
date >> ./0K_REPORT.txt

# For each input file given as argument
for input in "$@"; do
        # Create directory in QC folder following the same path than input path provided
        newdir=QC/${input}
        mkdir -p ${newdir}
        # Generate jobname replacing '/' by '_'
        name=`echo ${input} | sed -e 's@\/@_@g'`
        # Precise to eliminate empty lists for the loop
        shopt -s nullglob
        # Launch FastQC for each provided file
        for i in ${input}/*.fastq.gz ${input}/*.fq.gz; do
                # Set variables for jobname
                current_file=`echo $i | sed -e "s@${input}\/@@g" | sed -e "s@\.fastq\.gz\|\.fq\.gz@@g"`
                # Launch QC as a qsub
                echo -e "#$ -V \n#$ -cwd \n#$ -S /bin/bash \n\
                fastqc -o QC/${input} --noextract -f fastq $i" | qsub -N QC_${name}_${current_file}
                # Update REPORT
                echo -e "QC_${name}_${current_file} | fastqc -o QC/${input} --noextract -f fastq $i" >> ./0K_REPORT.txt  
        done
done
