#!/bin/env bash

################################################################################################################
### HELP -------------------------------------------------------------------------------------------------------
################################################################################################################
script_name='3_Trim.sh'

# Get user id for custom manual pathways
usr=`id | sed -e 's@).*@@g' | sed -e 's@.*(@@g'`

# Text font variables
END='\033[0m'
BOLD='\033[1m'
UDL='\033[4m'

# Show command manual
Help()
{
echo -e "${BOLD}####### TRIM MANUAL #######${END}\n\n\
${BOLD}SYNTHAX${END}\n\
    sh ${script_name} [options] <SE|PE> <input_dir>\n\n\
    
${BOLD}DESCRIPTION${END}\n\
    Perform trimming of paired or unpaired FASTQ files using Trimmomatic and/or file optimization and duplicates removal using Clumpify.\n\
    It creates a new folder './Trimmed/Trimmomatic' in which trimmed FASTQ files are stored, and './Trimmed/Clumpify' in which optimized files are stored.\n\
    If files are paired, trimming results are stored in subfolders './Trimmed/Trimmomatic/Paired' and './Trimmed/Trimmomatic/Unpaired'. In this case, it is recommended to use resulting paired files for following steps.\n\

${BOLD}OPTIONS${END}\n\
    ${BOLD}-U${END} ${UDL}tool${END}, ${BOLD}U${END}sedTool\n\
        Define tools to use for trimming. Could be 'Trimmomatic', 'Clumpify' or 'Both'. \n\
        Default = 'Trimmomatic'\n\n\

    ${BOLD}Trimmomatic Options${END}\n\n\
    ${BOLD}-S${END} ${UDL}windowSize${END}:${UDL}requiredQuality${END}, ${BOLD}S${END}lidingwindow\n\
        Performs a sliding window trimming approach. It starts scanning at the 5' end and clips the read once the average quality within the window falls below a threshold.\n\
        Default = 4:15\n\n\
    ${BOLD}-L${END} ${UDL}quality${END}, ${BOLD}L${END}eading\n\
        Cut bases off the start of a read, if below a threshold quality.\n\
        Default = 3\n\n\
    ${BOLD}-T${END} ${UDL}quality${END}, ${BOLD}T${END}railing\n\
        Cut bases off the end of a read, if below a threshold quality.\n\
        Default = 3\n\n\
    ${BOLD}-M${END} ${UDL}length${END}, ${BOLD}M${END}inlen\n\
        Drop the read if it is below a specified length.\n\
        Default = 36\n\n\
    ${BOLD}-I${END} ${UDL}fastaWithAdaptersEtc${END}:${UDL}seed mismatches${END}:${UDL}palindrome clip threshold${END}:${UDL}simple clip threshold${END}, ${BOLD}I${END}lluminaclip\n\
        Cut adapter and other illumina-specific sequences from the read.\n\
        Default = None\n\n\
For more details, please see Trimmomatic manual.\n\n\

    ${BOLD}Clumpify Options${END}\n\n\
    ${BOLD}-D${END} ${UDL}boolean${END}, ${BOLD}D${END}eduplicate\n\
        Whether remove diplicated reads.\n\
        Default = 'False'\n\n\

${BOLD}ARGUMENTS${END}\n\
    ${BOLD}<SE|PE>${END}\n\
        Define whether fastq files are Single-End (SE) or Paired-End (PE).\n\
        If SE is provided, each file is processed separately and give rise to an output file stored in ./Trimmed directory.\n\
        If PE is provided, files are trimmed in both paired and unpaired way, giving rise to four output files from a pair of input files.\n\n\
    ${BOLD}<input_dir>${END}\n\
        Directory containing .fastq.gz or .fq.gz files to use as input for trimming.\n\
        It usually corresponds to 'Raw'.\n\n\

${BOLD}EXAMPLE USAGE${END}\n\
    sh ${script_name} ${BOLD}-U${END} Both ${BOLD}-S${END} 4:15 ${BOLD}-L${END} 5 ${BOLD}-T${END} 5 ${BOLD}-M${END} 50 ${BOLD}-I${END} adapters_seq.fa:2:30:10 ${BOLD}-D${END} True ${BOLD}PE Raw${END}\n"
}

################################################################################################################
### OPTIONS ----------------------------------------------------------------------------------------------------
################################################################################################################

# Set default values
U_arg='Trimmomatic'
S_arg="4:15"
L_arg=3
T_arg=3
M_arg=36
I_arg='None'
D_arg='False'

# Change default values if another one is precised
while getopts ":U:S:L:T:M:I:D:" option; do
    case $option in
        S) # SLIDINGWINDOW
            S_arg=${OPTARG};;
        L) # LEADING
            L_arg=${OPTARG};;
        T) # TRAILING
            T_arg=${OPTARG};;
        M) # MINLEN
            M_arg=${OPTARG};;
        I) # ILLUMINACLIP
            I_arg=${OPTARG};;
        U) # USED TOOL(S)
            U_arg=${OPTARG};;
        D) # DEDUPE FOR CLUMPIFY
            D_arg=${OPTARG};;   
        \?) # Error
            echo "Error : invalid option"
            echo "      Allowed options are [-U|-S|-L|-T|-M|-I|-D]"
            echo "      Enter 'sh ${script_name} help' for more details"
            exit;;
    esac
done

# Checking if provided option values are correct
case $U_arg in
    TRIMMOMATIC|Trimmomatic|trimmomatic) 
        U_arg="Trimmomatic";;
    CLUMPIFY|Clumpify|clumpify) 
        U_arg="Clumpify";;
    BOTH|Both|both)
        U_arg="Both";;
    *) 
        echo "Error value : -U argument must be 'Trimmomatic', 'Clumpify' or 'Both'"
        exit;;
esac
case $I_arg in
    None) 
        I_arg='';;
    *) 
        I_arg='ILLUMINACLIP:'${I_arg}' ';;
esac
case $D_arg in
    True|true|TRUE|T|t) 
        D_arg='t';;
    False|false|FALSE|F|f) 
        D_arg='ILLUMINACLIP:'${I_arg};;
    *)
        echo "Error value : -D argument must be 'true' or 'false'"
        exit;;
esac

# Deal with options [-U|-S|-L|-T|-M|-I] and arguments [$1|$2]
shift $((OPTIND-1))

################################################################################################################
### ERRORS -----------------------------------------------------------------------------------------------------
################################################################################################################

# Count .fastq.gz or .fq.gz files in provided directory
files=$(shopt -s nullglob dotglob; echo $2/*.fastq.gz $2/*.fq.gz)
# Check format of I_arg if provided
adapters=$(shopt -s nullglob dotglob; echo $I_arg | grep -e '.*\.fa:.*:.*:.*')

if [ $# -eq 1 ] && [ $1 == "help" ]; then
    Help
    exit
elif [ $# -ne 2 ]; then
    # Error if inoccrect number of agruments is provided
    echo "Error synthax : please use following synthax"
    echo "       sh ${script_name} [options] <SE|PE> <input_dir>"
    exit
elif (( !${#files} )); then
    # Error if provided directory is empty or does not exists
    echo 'Error : can not find files in provided directory. Please make sure the provided directory exists, and contains .fastq.gz or .fq.gz files.'
    exit
elif [ $U_arg == "Trimmomatic" ] && [ $I_arg != '' ] && (( !${#adapters} )); then
    # Error if I_arg is precised but does not respect format
    echo "Error : invalid -I option format provided. For more details, please enter"
    echo "      sh ${script_name} help"
    exit
else
    # Error if the correct number of arguments is provided but the first does not match 'SE' or 'PE'
    case $1 in
        PE|SE) 
            ;;
        *) 
            echo "Error Synthax : please use following synthax"
            echo "       sh ${script_name} [options] <SE|PE> <input_dir>"
            exit;;
    esac
fi

################################################################################################################
### SCRIPT -----------------------------------------------------------------------------------------------------
################################################################################################################

# Generate REPORT
echo '#' >> ./0K_REPORT.txt
date >> ./0K_REPORT.txt

if [ $U_arg == "Trimmomatic" ]; then
    if [ $1 == "SE" ]; then
        # Create output directory
        outdir='Trimmed/Trimmomatic'
        mkdir -p ${outdir}
        # Precise to eliminate empty lists for the loop
        shopt -s nullglob
        # For each read file
        for i in $2/*.fastq.gz $2/*.fq.gz; do
            # Set variables for jobname
            current_file=`echo $i | sed -e "s@$2\/@@g" | sed -e 's@\.fastq\.gz\|\.fq\.gz@@g'`
            # Define output file
            output=${current_file}"_Trimmed.fastq.gz"
            # Launch Trimming in qsub without ILLUMINACLIP
            echo -e "#$ -V \n#$ -cwd \n#$ -S /bin/bash \n\
            conda activate base \n\
            conda activate Trimmomatic \n\
            trimmomatic SE -threads 4 $i \
            ${outdir}/${output} ${I_arg}\
            SLIDINGWINDOW:${S_arg} \
            LEADING:${L_arg} \
            TRAILING:${T_arg} \
            MINLEN:${M_arg}" | qsub -N Trim_${1}_${current_file}
            # Update REPORT
            echo -e "Trim_${1}_${current_file} | trimmomatic SE -threads 4 $i ${outdir}/${output} ${I_arg}SLIDINGWINDOW:${S_arg} LEADING:${L_arg} TRAILING:${T_arg} MINLEN:${M_arg}" >> ./0K_REPORT.txt
        done
    elif [ $1 == "PE" ]; then
        # Create output directories
        outdir='Trimmed/Trimmomatic'
        mkdir -p ${outdir}/{Paired,Unpaired}
        # Precise to eliminate empty lists for the loop
        shopt -s nullglob
        # For each read file
        for i in $2/*_R1*.fastq.gz $2/*_R1*.fq.gz; do
            # Define paired files
            R1=$i
            R2=`echo $i | sed -e 's/_R1/_R2/g'`
            # Set variables for jobname
            current_R1=`echo $i | sed -e "s@$2\/@@g" | sed -e 's@\.fastq\.gz\|\.fq\.gz@@g'`
            current_R2=`echo ${current_R1} | sed -e 's/_R1/_R2/g'`
            current_pair=`echo ${current_R1} | sed -e 's@_R1@@g'`
            # Define corresponding outputs for both paired and unpaired process
            P1=${current_R1}"_Trimmed_Paired.fastq.gz"
            U1=${current_R1}"_Trimmed_Unpaired.fastq.gz"
            P2=${current_R2}"_Trimmed_Paired.fastq.gz"
            U2=${current_R2}"_Trimmed_Unpaired.fastq.gz"
            # Launch qsub for each files
            # (if adapters detected, add : ILLUMINACLIP:Trimmed/NexteraPE-PE_Clontech-TTT.fa:2:30:10 )
            echo -e "#$ -V \n#$ -cwd \n#$ -S /bin/bash \n\
            conda activate base \n\
            conda activate Trimmomatic \n\
            trimmomatic PE -threads 4 $R1 $R2 \
            ${outdir}/Paired/${P1} ${outdir}/Unpaired/${U1} \
            ${outdir}/Paired/${P2} ${outdir}/Unpaired/${U2} ${I_arg}\
            SLIDINGWINDOW:${S_arg} \
            LEADING:${L_arg} \
            TRAILING:${T_arg} \
            MINLEN:${M_arg}" | qsub -N Trim_${1}_${current_pair}
            # Update REPORT
            echo -e "Trim_${1}_${current_file} | trimmomatic PE -threads 4 $R1 $R2 ${outdir}/Paired/${P1} ${outdir}/Unpaired/${U1} ${outdir}/Paired/${P2} ${outdir}/Unpaired/${U2} ${I_arg}SLIDINGWINDOW:${S_arg} LEADING:${L_arg} TRAILING:${T_arg} MINLEN:${M_arg}" >> ./0K_REPORT.txt
        done  
    fi
elif [ $U_arg == "Clumpify" ]; then
    module load bbmap
    # Create output directory
    outdir='Trimmed/Clumpify'
    mkdir -p ${outdir}
    # Precise to eliminate empty lists for the loop
    shopt -s nullglob
    # For each read file
    for i in $2/*.fastq.gz $2/*.fq.gz; do
        # Set variables for jobname
        current_file=`echo $i | sed -e "s@$2\/@@g" | sed -e 's@\.fastq\.gz\|\.fq\.gz@@g'`
        # Define output file
        output=${current_file}"_Clum.fastq.gz"
        # Launch qsub for fastq files
        echo -e "#$ -V \n#$ -cwd \n#$ -S /bin/bash \n\
        clumpify.sh in=${i} out=${outdir}/${output} dedupe=${D_arg} subs=0" | qsub -N Clumpify_${current_file}
        # Update REPORT
        echo -e "Clumpify_${current_file} | clumpify.sh in=${i} out=${outdir}/${output} dedupe=${D_arg} subs=0" >> ./0K_REPORT.txt
    done
elif [ $U_arg == "Both" ]; then
    module load bbmap
    # Create output directory
    outdir1='Trimmed/Clumpify'
    mkdir -p ${outdir1}
    outdir2='Trimmed/Trimmomatic'
    if [ $1 == "SE" ]; then
        # Create output directory
        outdir1='Trimmed/Clumpify'
        mkdir -p ${outdir1}
        outdir2='Trimmed/Trimmomatic'
        mkdir -p ${outdir2}
        # Precise to eliminate empty lists for the loop
        shopt -s nullglob
        # For each read file
        for i in $2/*.fastq.gz $2/*.fq.gz; do
            # Set variables for jobname
            current_file=`echo $i | sed -e "s@$2\/@@g" | sed -e 's@\.fastq\.gz\|\.fq\.gz@@g'`
            # Define output files
            output1=${current_file}"_Clum.fastq.gz"
            output2=${current_file}"_Clum_Trimmed.fastq.gz"
            # Launch qsub for fastq files
            echo -e "#$ -V \n#$ -cwd \n#$ -S /bin/bash \n\
            clumpify.sh in=${i} out=${outdir1}/${output1} dedupe=${D_arg} subs=0 \n\
            \n\
            conda activate base \n\
            conda activate Trimmomatic \n\
            trimmomatic SE -threads 4 ${outdir1}/${output1} \
            ${outdir2}/${output2} ${I_arg}\
            SLIDINGWINDOW:${S_arg} \
            LEADING:${L_arg} \
            TRAILING:${T_arg} \
            MINLEN:${M_arg}" | qsub -N ClumTrim_${1}_${current_file}
            # Update REPORT
            echo -e "Trim_${1}_${current_file} | clumpify.sh in=${i} out=${outdir1}/${output1} dedupe=${D_arg} subs=0" >> ./0K_REPORT.txt
            echo -e "                            trimmomatic SE -threads 4 $i ${outdir}/${output} ${I_arg}SLIDINGWINDOW:${S_arg} LEADING:${L_arg} TRAILING:${T_arg} MINLEN:${M_arg}" >> ./0K_REPORT.txt
        done
    elif [ $1 == "PE" ]; then
        # Create output directory exclusive of PE
        mkdir -p ${outdir2}/{Paired,Unpaired}
        # Precise to eliminate empty lists for the loop
        shopt -s nullglob
        # For each read file
        for i in $2/*_R1*.fastq.gz $2/*_R1*.fq.gz; do
            # Define Clumpify input paired file
            i_2=`echo $i | sed -e 's@_R1@_R2@g'`
            # Define Clumpify outputs paired files
            ClumOut1=`echo $i | sed -e "s@$2\/@@g" | sed -e 's@\.fastq\.gz\|\.fq\.gz@_Clum\.fastq\.gz@g'`
            ClumOut2=`echo ${ClumOut1} | sed -e 's@_R1@_R2@g'`
            # Set variables for jobname
            current_R1=`echo ${ClumOut1} | sed -e 's@\.fastq\.gz\|\.fq\.gz@@g'`
            current_R2=`echo ${current_R1} | sed -e 's/_R1/_R2/g'`
            current_pair=`echo ${current_R1} | sed -e 's@_R1@@g'`
            # Define corresponding outputs for both paired and unpaired process
            P1=${current_R1}"_Trimmed_Paired.fastq.gz"
            U1=${current_R1}"_Trimmed_Unpaired.fastq.gz"
            P2=${current_R2}"_Trimmed_Paired.fastq.gz"
            U2=${current_R2}"_Trimmed_Unpaired.fastq.gz"
            # Launch qsub for each files
            echo -e "#$ -V \n#$ -cwd \n#$ -S /bin/bash \n\
            clumpify.sh in=${i} out=${outdir1}/${ClumOut1} dedupe=${D_arg} subs=0 \n\
            clumpify.sh in=${i_2} out=${outdir1}/${ClumOut2} dedupe=${D_arg} subs=0 \n\
            \n\
            conda activate base \n\
            conda activate Trimmomatic \n\
            trimmomatic PE -threads 4 ${outdir1}/${ClumOut1} ${outdir1}/${ClumOut2} \
            ${outdir2}/Paired/${P1} ${outdir2}/Unpaired/${U1} \
            ${outdir2}/Paired/${P2} ${outdir2}/Unpaired/${U2} ${I_arg}\
            SLIDINGWINDOW:${S_arg} \
            LEADING:${L_arg} \
            TRAILING:${T_arg} \
            MINLEN:${M_arg}" | qsub -N ClumTrim_${1}_${current_pair}
            # Update REPORT
            echo -e "Trim_${1}_${current_file} | clumpify.sh in=${i} out=${outdir1}/${ClumOut1} dedupe=${D_arg} subs=0" >> ./0K_REPORT.txt
            echo -e "                            clumpify.sh in=${i_2} out=${outdir1}/${ClumOut2} dedupe=${D_arg} subs=0" >> ./0K_REPORT.txt
            echo -e "                            trimmomatic PE -threads 4 $R1 $R2 ${outdir}/Paired/${P1} ${outdir}/Unpaired/${U1} ${outdir}/Paired/${P2} ${outdir}/Unpaired/${U2} ${I_arg}SLIDINGWINDOW:${S_arg} LEADING:${L_arg} TRAILING:${T_arg} MINLEN:${M_arg}" >> ./0K_REPORT.txt
        
        done 
    fi
fi
