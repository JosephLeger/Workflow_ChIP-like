#!/bin/env bash

################################################################################################################
### HELP -------------------------------------------------------------------------------------------------------
################################################################################################################
script_name='3_Bowtie2.sh'

# Get user id for custom manual pathways
usr=`id | sed -e 's@).*@@g' | sed -e 's@.*(@@g'`

# Text font variables
END='\033[0m'
BOLD='\033[1m'
UDL='\033[4m'

# Show command manual
Help()
{
echo -e "${BOLD}####### BOWTIE2 MANUAL #######${END}\n\n\
${BOLD}SYNTHAX${END}\n\
	sh ${script_name} [options] <SE|PE> <input_dir> <refindex>\n\n\

${BOLD}DESCRIPTION${END}\n\
	Perform alignement on reference genome from paired or unpaired FASTQ files using Bowtie2, and sort resulting BAM files using Picard.\n\
	It creates new folder './Mapped/<model>/BAM' in which resulting aligned and sorted BAM files are stored.\n\n\

${BOLD}OPTIONS${END}\n\
	${BOLD}-M${END} ${UDL}str${END}, ${BOLD}M${END}ode\n\
		Mode of run to apply for alignment.\n\
			default  : use default Bowtie2 parameters\n\
			henikoff : --end-to-end --very-sensitive --no-mixed --no-discordant\n\
			spike    : --end-to-end --very-sensitive --no-mixed --no-discordant --no-overlap --no-dovetail\n\
		Default = 'default'\n\n\
	${BOLD}-U${END} ${UDL}boolean${END}, ${BOLD}U${END}nalignedReadsRemoval\n\
		Whether remove unaligned reads to output file. \n\
		Default = 'false'\n\n\

${BOLD}ARGUMENTS${END}\n\
	${BOLD}<SE|PE>${END}\n\
		Define whether fastq files are Single-End (SE) or Paired-End (PE).\n\
		If SE is provided, each file is aligned individually and give rise to an output file.\n\
		If PE is provided, files are aligned by pair (R1 and R2), giving rise to a single output file from a pair of input files.\n\n\
	${BOLD}<input_dir>${END}\n\
		Directory containing .fastq.gz or .fq.gz files to use as input for alignment.\n\
		It usually corresponds to 'Raw' or 'Trimmed/Trimmomatic'.\n\n\
	${BOLD}<refindex>${END}\n\
		Path to reference previously indexed using bowtie2-build.\n\
		Provided path must be ended by reference name (prefix common to files).\n\n\
        
${BOLD}EXAMPLE USAGE${END}\n\
	sh ${script_name} -M default ${BOLD}SE Trimmed/Trimmomatic ${usr}/Ref/refdata-Bowtie2-mm39/mm39${END}\n"
}

################################################################################################################
### OPTIONS ----------------------------------------------------------------------------------------------------
################################################################################################################

# Set default values
M_arg='default'
U_arg='false'
N_arg=0

# Change default values if another one is precised
while getopts ":M:U:" option; do
	case $option in
		M) # MODE OF RUN
			M_arg=${OPTARG};;
		U) # UNALIGNED
			U_arg=${OPTARG};;
		\?) # Error
			echo "Error : invalid option"
			echo "      Allowed options are [-M|-U]"
			echo "      Enter 'sh ${script_name} help' for more details"
			exit;;
	esac
done

# Checking if provided option values are correct
case $M_arg in
	default|Default|DEFAULT) 
		M_arg='';;
	henikoff|Henikoff|HENIKOFF) 
		M_arg='--end-to-end --very-sensitive --no-mixed --no-discordant ';;
	spike|Spike|SPIKE) 
		M_arg='--end-to-end --very-sensitive --no-mixed --no-discordant --no-overlap --no-dovetail ';;
	*) 
		echo "Error value : -M argument must be 'default', 'henikoff' or 'spike'"
		exit;;
esac
case $U_arg in
	TRUE|True|true|T|t) 
		U_arg='--no-unal ';;
	FALSE|False|false|F|f) 
		U_arg='';;
	*) 
		echo "Error value : -U argument must be 'true' or 'false'"
		exit;;
esac


# Deal with options [-U|-L|-N] and arguments [$1|$2]
shift $((OPTIND-1))

################################################################################################################
### ERRORS -----------------------------------------------------------------------------------------------------
################################################################################################################

if [ $# -eq 1 ] && [ $1 == "help" ]; then
	Help
	exit
elif [ $# -ne 3 ]; then
	# Error if inoccrect number of agruments is provided
	echo "Error synthax : please use following synthax"
	echo "      sh ${script_name} <SE|PE> <input_dir> <refindex>"
	exit
elif [ $(ls $2/*.fastq.gz $2/*.fq.gz 2>/dev/null | wc -l) -lt 1 ]; then
	# Error if provided directory is empty or does not exists
	echo -e "Error : can not find files in $2 directory. Please make sure the provided directory exists, and contains .fastq.gz or .fq.gz files."
	exit
elif [ $1 == "PE" ] && [[ $(ls $2/*_R1*.fastq.gz $2/*_R1*.fq.gz 2>/dev/null | wc -l) -eq 0 || $(ls $2/*_R1*.fastq.gz $2/*_R1*.fq.gz 2>/dev/null | wc -l) -ne $(ls $2/*_R2*.fastq.gz $2/*_R2*.fq.gz 2>/dev/null | wc -l) ]]; then
	# Error if PE is selected but no paired files are detected
	echo 'Error : PE is selected but can not find R1 and R2 files for each pair. Please make sure files are Paired-End.'
	exit
else
	# Error if the correct number of arguments is provided but the first does not match 'SE' or 'PE'
	case $1 in
		PE|SE) 
			;;
        	*) 
			echo "Error Synthax : please use following synthax"
			echo "       sh ${script_name} <SE|PE> <input_dir> <refindex>"
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

# Create output directories
model=`echo $3 | sed -r 's/^.*\/(.*)$/\1/'`
mkdir -p ./Mapped/${model}/{BAM,STAT}

## BOWTIE2 - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
if [ $1 == "SE" ]; then
	# Set up parameters for SLURM ressources
	TIME='0-01:00:00'; NODE='1'; TASK='1'; CPU='4'; MEM='10g'; QOS='quick'

	# Initialize JOBLIST to wait before running MultiQC
	JOBLIST='_'
	# Precise to eliminate empty lists for the loop
	shopt -s nullglob
	# For each read file
	for i in $2/*.fq.gz $2/*.fastq.gz; do
		# Set variables for jobname
		current_file=`echo $i | sed -e "s@${2}\/@@g" | sed -e 's@\.fastq\.gz\|\.fq\.gz@@g'`
		# Define JOBNAME and COMMAND and launch job while append JOBLIST
		JOBNAME="Bowtie2_${1}_${model}_${current_file}"
		COMMAND="(bowtie2 -p 4 ${M_arg}${U_arg}\
		-x $3 -U $i | samtools sort -o  Mapped/${model}/BAM/${current_file}_sorted.bam) 3>&1 1>&2 2>&3 | tee Mapped/${model}/STAT/Stat_${model}_${current_file}.txt"
		Launch
		JOBLIST=${JOBLIST}':'${JOBID}
	done
	# Set location variables for summarizing stat results from SE
	loc_depth='1p'
	loc_mono_mapped='4p'
	loc_multi_mapped='5p'
	loc_rate='6p'

elif [ $1 == "PE" ]; then
	# Set up parameters for SLURM ressources
	TIME='0-01:30:00'; NODE='1'; TASK='1'; CPU='4'; MEM='10g'; QOS='quick'

	# Initialize JOBLIST to wait before running MultiQC
	JOBLIST='_'
	# Precise to eliminate empty lists for the loop
	shopt -s nullglob
	# If PE (Paired-End) is selected, each paired files are aligned together
	for i in $2/*_R1*.fastq.gz $2/*_R1*.fq.gz; do
		# Set variables for jobname
		current_pair=`echo $i | sed -e "s@${2}\/@@g" | sed -e 's/_R1//g' | sed -e 's@\.fastq\.gz\|\.fq\.gz@@g'`
		# Define paired files
		R1=$i
		R2=`echo $i | sed -e 's/_R1/_R2/g'`
		# Define JOBNAME and COMMAND and launch job while append JOBLIST
		JOBNAME="Bowtie2_${1}_${model}_${current_pair}"
		COMMAND="(bowtie2 -p 4 -q ${M_arg}${U_arg}\
		-x $3 -1 ${R1} -2 ${R2}) 2> Mapped/${model}/STAT/Stat_${model}_${current_file}.txt | picard SortSam INPUT=/dev/stdin \
		OUTPUT=Mapped/${model}/BAM/${current_pair}_sorted.bam \
		VALIDATION_STRINGENCY=LENIENT \
		TMP_DIR=tmp \
		SORT_ORDER=coordinate"
		Launch    
		JOBLIST=${JOBLIST}':'${JOBID}
	done
	# Set location variables for summarizing stat results from PE
	loc_depth='1p'
	loc_mono_mapped='4p'
	loc_multi_mapped='5p'
	loc_rate='6p'
fi

## SUMMARIZE STATS - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Set up parameters for SLURM ressources
TIME='0-00:03:00'; NODE='1'; TASK='1'; CPU='1'; MEM='1g'; QOS='quick'

# Prepare summary file and WAIT list
echo "Filename,SequencingDepth,Mono_MappedFragNum_${model},Multi_MappedFragNum_${model},Total_MappedFragNum_${model},AlignmentRate_${model}" > Mapped/${model}/STAT/Summary_Stats_${model}.csv
# Initialize WAIT based on JOBLIST (empty or not)
WAIT=`echo ${JOBLIST} | sed -e 's@_@-d afterany@'`

# Unset Shopt Builtin (necessary for the following Job)
shopt -u nullglob

# Define JOBNAME and COMMAND and launch job using setted WAIT list
JOBNAME="Summarize_Stats_${model}"
COMMAND="for stat in Mapped/${model}/STAT/*.txt; do \n\
file=\`echo \${stat} | sed -e 's@\/STAT\/@\/BAM\/@g' | sed -e "s@Stat_${model}_@@g" | sed -e 's@\.txt@_sorted\.bam@g'\` \n\
depth=\`cat \${stat} | sed -n '1p' | sed -e \"s@ .*@@g\"\` \n\
mono_mapped=\`cat \${stat} | sed -n '4p' | sed -e 's@ *@@' | sed -e 's@ .*@@g'\` \n\
multi_mapped=\`cat \${stat} | sed -n '5p' | sed -e 's@ *@@' | sed -e 's@ .*@@g'\` \n\
mapped=\`echo \${mono_mapped}'+'\${multi_mapped} | bc\` \n\
rate=\`cat \${stat} | sed -n '6p' | sed -e 's@ .*@@g'\` \n\
echo "\${file},\${depth},\${mono_mapped},\${multi_mapped},\${mapped},\${rate}" >> Mapped/${model}/STAT/Summary_Stats_${model}.csv \n\
done"
Launch
