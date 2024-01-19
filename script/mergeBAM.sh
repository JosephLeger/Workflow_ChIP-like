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
    Merge BAM files matching a pattern into a unique BAM file using samtools merge.\n\
    Can be used for calling peaks on an accumulation of experiments to have higher signals.\n\
    It requires sample information in a provided .csv file (see example_sheet_sample.csv).\n\n\

${BOLD}OPTIONS${END}\n\
    ${BOLD}-N${END} ${UDL}suffix${END}, ${BOLD}N${END}amePattern\n\
        Define a suffix that input files must share to be considered. Allows to exclude BAM files that are unfiltered or unwanted.\n\
        Default = '_sorted_unique_filtered'\n\n\
    ${BOLD}-M${END} ${UDL}mark${END}, ${BOLD}M${END}ark\n\
        Define epigenetic mark present in <sheet_sample.csv> to consider for merging.\n\
        Default = <current_dirname>\n\n\
    ${BOLD}-R${END} ${UDL}boolean${END}, ${BOLD}R${END}emoveSuffix\n\
        Specify whether provided suffix from input filename have to be removed in output filename.\n\
        Default = false\n\n\

${BOLD}ARGUMENTS${END}\n\
    ${BOLD}<input_dir>${END}\n\
        Directory containing .bam files to process.\n\
        It usually corresponds to 'Mapped/<model>/BAM'.\n\n\
    ${BOLD}<sheet_sample.csv>${END}\n\
        Path to .csv files containing sample information stored in 4 columns : 1)Sample_ID 2)Filename[not used] 3)Condition1 4)Condition2.\n\n\

${BOLD}EXAMPLE USAGE${END}\n\
    sh ${script_name} ${BOLD}-N${END} _sorted_unique_filtered ${BOLD}-M${END} H3K4me3 ${BOLD}-R${END} true ${BOLD}Mapped/mm39/BAM ../SRA_ChIC-seq.csv${END}\n"
}

################################################################################################################
### OPTIONS ----------------------------------------------------------------------------------------------------
################################################################################################################

# Set default values
N_arg='_sorted_unique_filtered'
M_arg=`pwd | sed -e 's@.*\/@@g'`
R_arg='false'

# Change default values if another one is precised
while getopts ":M:N:R:" option; do
    case $option in
        M) # CURRENT EPIGENETIC MARK TO MERGE
            M_arg=${OPTARG};;
        N) # NAME OF FILE (SUFFIX)
            N_arg=${OPTARG};;
        R) # REMOVE SUFFIX IN OUTPUT FILENAME
            R_arg=${OPTARG};;
        \?) # Error
            echo "Error : invalid option"
            echo "      Allowed options are [-N|-M|-R]"
            echo "      Enter 'sh ${script_name} help' for more details"
            exit;;
        esac
done

# Checking if provided option values are correct
case $R_arg in
    true|TRUE|True|T) 
        newsuffix='_merged.bam';;
    false|FALSE|False|F)
        newsuffix=${S_arg}'_merged.bam';;
    *) 
        echo "Error value : -R argument must be 'true' or 'false'"
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
elif [ $# != 2 ]; then
    # Error if arguments are missing
    echo "Error synthax : please use following synthax"
    echo "      sh ${script_name} <input_dir> <data_sheet.csv>"
    exit
else
    # Count .bam files matching -N pattern in provided directory
    files=$(shopt -s nullglob dotglob; echo ${1}/*${N_arg}*.bam)
    if (( !${#files} )); then
        # Error if current provided directory is empty or does not exists
        echo -e "Error : can not find files to sort in ${input} directory. Please make sure the provided input directory exists, and contains correct .bam files."
        exit
    fi
fi

################################################################################################################
### SCRIPT -----------------------------------------------------------------------------------------------------
################################################################################################################

module load samtools/1.15.1

# Generate REPORT
echo '#' >> ./0K_REPORT.txt
date >> ./0K_REPORT.txt

# Establish conditions_list which contains already visited condition2 (celltype)
conditions_list=""
while IFS=',' read -r sra filename cond1 cond2; do
    # Read the entire sheet cond2 columns
    cond2=$(echo $cond2 | tr -d '\r')
    # Check if current $cond2 is already written in $conditions_list
    is_present=`echo $conditions_list | grep -ce $cond2`

    # If $cond2 is not written yet in $conditions_list
    if [ $is_present -eq 0 ]; then
        # Add it to the list to not visiting it again
        conditions_list="${conditions_list} ${cond2}"

        # Initialize $sra_file list to store filenames to merge
        sra_files=""
        # Look for $sra in the entire sheet that share current $cond2 and $M_arg
        while IFS=',' read -r sra filename cond1 cond22; do
            sra=$(echo $sra | tr -d '\r')
            cond22=$(echo $cond22 | tr -d '\r')
            if [ "$cond22" == "$cond2" ] && [[ "$cond1" == "$M_arg" ]]; then
                # Search for $files correspoinding to current matching $sra
                newfile=`find ${1} -type f -iname "*${sra}*${N_arg}*.bam"`
                sra_files="${sra_files} ${newfile}"
            fi
        done < ${2}
        # Launch qsub    
        echo -e "#$ -V \n#$ -cwd \n#$ -S /bin/bash \n\
        samtools merge -o ${1}/${M_arg}_${cond2}${newsuffix} ${sra_files} \n\
        samtools index ${1}/${M_arg}_${cond2}${newsuffix}" | qsub -N mergeBAM_${M_arg}_${cond2}
        # Update REPORT
        echo -e "mergeBAM_${M_arg}_${cond2} | fastqc -o QC/${input} --noextract -f fastq $i" >> ./0K_REPORT.txt
        echo -e "        | samtools merge -o ${1}/${M_arg}_${cond2}${newsuffix} ${sra_files}" >> ./0K_REPORT.txt
        echo -e "        | samtools index ${1}/${M_arg}_${cond2}${newsuffix}" >> ./0K_REPORT.txt
        
    fi
done < ${2}
