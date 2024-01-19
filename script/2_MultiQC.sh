#!/bin/env bash

################################################################################################################
### HELP -------------------------------------------------------------------------------------------------------
################################################################################################################
script_name='MultiQC.sh'

# Get user id for custom manual pathways
usr=`id | sed -e 's@).*@@g' | sed -e 's@.*(@@g'`

# Text font variables
END='\033[0m'
BOLD='\033[1m'
UDL='\033[4m'

# Show command manual
Help()
{
echo -e "${BOLD}####### MULTIQC MANUAL #######${END}\n\n\
${BOLD}SYNTHAX${END}\n\
        sh ${script_name} <input_dir>\n\n\

${BOLD}DESCRIPTION${END}\n\
        Generate a grouped visualization of several quality check results from FastQC.\n\
        It creates a new folder './QC/MultiQC' in which input results files are merged into a single file.\n\
        Output files are a unique .html file for direct visualization and a corresponding .zip file containing results.\n\n\

${BOLD}ARGUMENTS${END}\n\
        ${BOLD}<input_dir>${END}\n\
                Directory containing correct input files.
                Correct inputs can be ${BOLD}.zip${END} results files from FastQC quality check, STAR outputs ${BOLD}Log.final.out${END} files, or RSEM result folder containing subfolders with ${BOLD}.cnt${END} files.\n\
                Note that MultiQC looks for files in all subdirectories of provided input directory.\n\n\

${BOLD}EXAMPLE USAGE${END}\n\
        sh ${script_name} ${BOLD}QC/Raw${END}\n"
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
fi

################################################################################################################
### SCRIPT -----------------------------------------------------------------------------------------------------
################################################################################################################

module load multiqc/1.13

# Generate REPORT
echo '#' >> ./0K_REPORT.txt
date >> ./0K_REPORT.txt

# Create directory in QC folder for MultiQC
newdir='./QC/MultiQC'
mkdir -p ${newdir}
# Create output name without strating 'QC/' and replacing '/' by '_'
name=`echo $1 | sed -e 's@\/@_@g'`
# Launch multiQC
echo -e "#$ -V \n#$ -cwd \n#$ -S /bin/bash \n\
multiqc $1 -o ${newdir} -n ${name}_MultiQC" | qsub -N MultiQC_${name}
echo -e "MultiQC_${name} | multiqc $1 -o ${newdir} -n ${name}_MultiQC" >> ./0K_REPORT.txt
