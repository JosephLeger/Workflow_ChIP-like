#!/bin/env bash

################################################################################################################
### HELP -------------------------------------------------------------------------------------------------------
################################################################################################################
script_name='2_Trim.sh'

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
	Perform file optimization and duplicates removal using Clumpify or/and trimming of paired or unpaired FASTQ files using Trimmomatic.\n\
	It creates new folders './Trimmed/Clumpify' in which optimized files are stored and './Trimmed/Trimmomatic' in which trimmed FASTQ files are stored.\n\
	If files are paired, trimming results are stored in subfolders './Trimmed/Trimmomatic/Paired' and './Trimmed/Trimmomatic/Unpaired'. In this case, it is recommended to use resulting paired files for following steps.\n\

${BOLD}OPTIONS${END}\n\
	${BOLD}-U${END} ${UDL}tool${END}, ${BOLD}U${END}sedTool\n\
		Define tools to use for filtering. Could be 'Trimmomatic', 'Clumpify' or 'Both'. \n\
		Default = 'Trimmomatic'\n\n\

	${BOLD}Trimmomatic Options${END}\n\n\
	${BOLD}-S${END} ${UDL}windowSize${END}:${UDL}requiredQuality${END}, ${BOLD}S${END}lidingwindow\n\
		Perform a sliding window trimming approach. It starts scanning at the 5' end and clips the read once the average quality within the window falls below a threshold.\n\
		Default = 4:15\n\n\
	${BOLD}-L${END} ${UDL}quality${END}, ${BOLD}L${END}eading\n\
		Cut bases off the start of a read, if below a threshold quality.\n\
		Default = 3\n\n\
	${BOLD}-T${END} ${UDL}quality${END}, ${BOLD}T${END}railing\n\
		Cut bases off the end of a read, if below a threshold quality.\n\
		Default = 3\n\n\
	${BOLD}-M${END} ${UDL}length${END}, ${BOLD}M${END}inlen\n\
		Drop the read if it is below a specified length.\n\
		Default = 1\n\n\
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
		If SE is provided, each file is processed separately and give rise to an output file stored in output directory.\n\
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
M_arg=1
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
		U_arg="Trimmomatic"
		indir_2=${@: -1}
		suffix='';;
	CLUMPIFY|Clumpify|clumpify) 
		U_arg="Clumpify";;
	BOTH|Both|both)
		U_arg="Both"
		indir_2='Trimmed/Clumpify'
		suffix='_Clum';;
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
		D_arg='f';;
	*)
		echo "Error value : -D argument must be 'true' or 'false'"
		exit;;
esac

# Deal with options [-U|-S|-L|-T|-M|-I] and arguments [$1|$2]
shift $((OPTIND-1))

################################################################################################################
### ERRORS -----------------------------------------------------------------------------------------------------
################################################################################################################

if [ $# -eq 1 ] && [ $1 == "help" ]; then
	Help
	exit
elif [ $# -ne 2 ]; then
	# Error if inoccrect number of agruments is provided
	echo "Error synthax : please use following synthax"
	echo "       sh ${script_name} [options] <SE|PE> <input_dir>"
	exit
elif [ $(ls $2/*.fastq.gz $2/*.fq.gz 2>/dev/null | wc -l) -lt 1 ]; then
	# Error if provided directory is empty or does not exists
	echo 'Error : can not find files to align in provided directory. Please make sure the provided input directory exists, and contains .fastq.gz or .fq.gz files.'
	exit
elif [ $1 == "PE" ] && [[ $(ls $2/*_R1*.fastq.gz $2/*_R1*.fq.gz 2>/dev/null | wc -l) -eq 0 || $(ls $2/*_R1*.fastq.gz $2/*_R1*.fq.gz 2>/dev/null | wc -l) -ne $(ls $2/*_R2*.fastq.gz $2/*_R2*.fq.gz 2>/dev/null | wc -l) ]]; then
	# Error if PE is selected but no paired files are detected
	echo 'Error : PE is selected but can not find R1 and R2 files for each pair. Please make sure files are Paired-End.'
	exit
elif ([ $U_arg == "Trimmomatic" ] || [ $U_arg == "Both" ]) && [ -n "$I_arg" ] && [[ ! ${I_arg} =~ ^.*\.fa:.*:.*: ]]; then
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

## SETUP - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
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

# Set default file extention
file_ext='fastq.gz'

## DEFINE FUNCTIONS - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
CLUMPIFY_launch()
{
module load bbmap/39.00
# Create output directory
outdir='Trimmed/Clumpify'
mkdir -p ${outdir}
# Initialize JOBLIST for WAIT
JOBLIST='_'
if [ ${1} == "SE" ]; then
	# Precise to eliminate empty lists for the loop
	shopt -s nullglob
	# For each read file
	for i in ${2}/*.fastq.gz ${2}/*.fq.gz; do
		# Set variables for jobname
		current_file=`echo $i | sed -e "s@${2}\/@@g" | sed -e 's@\.fastq\.gz\|\.fq\.gz@@g'`
		# Define JOBNAME and COMMAND and launch job
		JOBNAME="Clumpify_${current_file}"
		COMMAND="clumpify.sh in=${i} out=${outdir}/${current_file}_Clum.fastq.gz dedupe=${D_arg} subs=0"
		JOBLIST=${JOBLIST}','${JOBNAME}
		Launch
	done
elif [ ${1} == "PE" ]; then
	# Precise to eliminate empty lists for the loop
	shopt -s nullglob
	# For each read file
	for i in ${2}/*_R1*.fastq.gz ${2}/*_R1*.fq.gz; do
		# Define paired files
		R1=${i}
		R2=`echo ${i} | sed -e 's@_R1@_R2@g'`
		# Set variables for jobname
		current_R1=`echo $i | sed -e "s@${2}\/@@g" | sed -e 's@\.fastq\.gz\|\.fq\.gz@@g'`
		current_R2=`echo ${current_R1} | sed -e 's/_R1/_R2/g'`
		current_pair=`echo ${current_R1} | sed -e 's@_R1@@g'`
		# Define JOBNAME and COMMAND and launch job
		JOBNAME="Clumpify_${current_pair}"
		COMMAND="clumpify.sh in=${R1} in2=${R2} out=${outdir}/${current_R1}_Clum.fastq.gz out2=${outdir}/${current_R2}_Clum.fastq.gz dedupe=${D_arg} subs=0"
		JOBLIST=${JOBLIST}','${JOBNAME}
  		Launch
	done
fi
}

TRIMMOMATIC_launch()
{
# Create output directory
outdir='Trimmed/Trimmomatic'
mkdir -p ${outdir}
# Initialize WAIT based on JOBLIST (empty or not)
WAIT=`echo ${JOBLIST} | sed -e 's@_,@-hold_jid @'`
if [ ${1} == "SE" ]; then
	# Precise to eliminate empty lists for the loop
	shopt -s nullglob
	# For each read file
	for i in ${2}/*.fastq.gz ${2}/*.fq.gz; do
		# Modify default extension if necessary
		if [ `echo ${i} | grep 'fq.gz$' | wc -l` -eq 1 ]; then file_ext='fq.gz'; fi
		# Set variables for jobname
		current_file=`echo $i | sed -e "s@${2}\/@@g" | sed -e "s@\.${file_ext}@@g"`
		# Define JOBNAME and COMMAND and launch job
		JOBNAME="Trim_${1}_${current_file}"
		COMMAND="conda activate base \n\
		conda activate Trimmomatic \n\
		trimmomatic ${1} -threads 4 ${indir_2}/${current_file}${suffix}.${file_ext} \
		${outdir}/${current_file}${suffix}"_Trimmed.fastq.gz" ${I_arg}\
		SLIDINGWINDOW:${S_arg} \
		LEADING:${L_arg} \
		TRAILING:${T_arg} \
		MINLEN:${M_arg}"
		Launch
	done
elif [ ${1} == "PE" ]; then
	mkdir -p ${outdir}/{Paired,Unpaired}
	# Precise to eliminate empty lists for the loop
	shopt -s nullglob
	# For each read file
	for i in ${2}/*_R1*.fastq.gz ${2}/*_R1*.fq.gz; do
		# Modify default extension if necessary
		if [ `echo ${i} | grep 'fq.gz$' | wc -l` -eq 1 ]; then file_ext='fq.gz'; fi
		# Define paired files
		R1=${i}
		R2=`echo ${i} | sed -e 's/_R1/_R2/g'`
		# Set variables for jobname
		current_R1=`echo $i | sed -e "s@${2}\/@@g" | sed -e "s@\.${file_ext}@@g"`
		current_R2=`echo ${current_R1} | sed -e 's/_R1/_R2/g'`
		current_pair=`echo ${current_R1} | sed -e 's@_R1@@g'`
		# Define JOBNAME and COMMAND and launch job
		JOBNAME="Trim_${1}_${current_pair}"
		COMMAND="conda activate Trimmomatic \n\
		trimmomatic ${1} -threads 4 ${indir_2}/${current_R1}${suffix}.${file_ext} ${indir_2}/${current_R2}${suffix}.${file_ext} \
		${outdir}/Paired/${current_R1}${suffix}_Trimmed_Paired.fastq.gz \
		${outdir}/Unpaired/${current_R1}${suffix}_Trimmed_Unpaired.fastq.gz \
		${outdir}/Paired/${current_R2}${suffix}_Trimmed_Paired.fastq.gz \
		${outdir}/Unpaired/${current_R2}${suffix}_Trimmed_Unpaired.fastq.gz ${I_arg}\
		SLIDINGWINDOW:${S_arg} \
		LEADING:${L_arg} \
		TRAILING:${T_arg} \
		MINLEN:${M_arg}"
		Launch
	done 
fi
}

## LAUNCH COMMANDS - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
if [ $U_arg == "Clumpify" ]; then
	CLUMPIFY_launch $1 $2
elif [ $U_arg == "Trimmomatic" ]; then
	TRIMMOMATIC_launch $1 $2
elif [ $U_arg == "Both" ]; then
	CLUMPIFY_launch $1 $2
	TRIMMOMATIC_launch $1 $2
fi
