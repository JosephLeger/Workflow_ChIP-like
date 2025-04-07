#!/bin/env bash

################################################################################################################
### HELP -------------------------------------------------------------------------------------------------------
################################################################################################################
script_name='BAM2BW.sh'

# Get user id for custom manual pathways
usr=`id | sed -e 's@).*@@g' | sed -e 's@.*(@@g'`

# Text font variables
END='\033[0m'
BOLD='\033[1m'
UDL='\033[4m'

# Show command manual
Help()
{
echo -e "${BOLD}####### BAM2BW MANUAL #######${END}\n\n\
${BOLD}SYNTHAX${END}\n\
	sh ${script_name} [options] <input_dir>\n\n\

${BOLD}DESCRIPTION${END}\n\
	Perform conversion of BAM files to BigWig format using deeptools bamCoverage.\n\
	It creates a new folder 'BIGWIG' next to the input directory in which output files are stored.\n\n\
    
${BOLD}OPTIONS${END}\n\
	${BOLD}-N${END} ${UDL}suffix${END}, ${BOLD}N${END}amePattern\n\
		Define a suffix that input files must share to be considered. Allows to exclude unwanted BAM files.\n\
		Default = _filtered\n\n\
	${BOLD}-F${END} ${UDL}outFormat${END}, ${BOLD}F${END}ormat\n\
		Select output files format. Must be in 'bigwig' or 'bedgraph'.\n\
		Default = bigwig\n\n\
	${BOLD}-M${END} ${UDL}normalizationMethod${END}, Normalization${BOLD}M${END}ethod\n\
		Select nromalization method to apply. Must be in 'RPKM', 'CPM', 'BPM', 'RPGC' or 'None'.\n\
		Default = None\n\n\
	${BOLD}-R${END} ${UDL}boolean${END}, ${BOLD}R${END}emoveSuffix\n\
		Precise whether specified suffix from input filename (-N argument) have to be removed from output filename.\n\
		Default = false\n\n\

${BOLD}ARGUMENTS${END}\n\
	${BOLD}<input_dir>${END}\n\
		Directory containing BAM files to process.\n\
		It usually corresponds to 'Mapped/<model>/BAM'.\n\n\

${BOLD}EXAMPLE USAGE${END}\n\
	sh ${script_name} ${BOLD}-N${END} _sorted_unique_filtered ${BOLD}-F${END} bigwig ${BOLD}-M${END} RPKM ${BOLD}-R${END} true ${BOLD}Mapped/mm39/BAM${END}\n"
}

################################################################################################################
### OPTIONS ----------------------------------------------------------------------------------------------------
################################################################################################################

# Set default values
N_arg="_filtered"
F_arg="bigwig"
M_arg="None"
R_arg="false"

# Change default values if another one is precised
while getopts ":N:F:M:R:" option; do
	case $option in
		N) # SUFFIX TO DISCRIMINATE FILES FOR INPUT
			N_arg=${OPTARG};;
		F) # FORMAT FOR OUTPUT FILE
			F_arg=${OPTARG};;
		M) # NORMALIZATION TO APPLY
			M_arg=${OPTARG};;
		R) # REMOVE SUFFIX IN OUTPUT FILENAME
			R_arg=${OPTARG};;
		\?) # Error
			echo "Error : invalid option"
			echo "      Allowed options are [-N|-F|-M|-R]"
			echo "      Enter sh Bam2BW.sh help for more details"
			exit;;
	esac
done

# Checking if provided option values are correct
case $F_arg in
	bedgraph|BedGraph|BG|bg) 
		F_arg="bedgraph"
		file_ext="bedgraph"
		out_dir="BEDGRAPH";;
	bigwig|BigWig|BW|bw)
		F_arg="bigwig"
		file_ext="bw"
		out_dir="BIGWIG";;
	*) 
		echo "Error value : -F argument must be 'bigwig' or 'bedgraph'"
		exit;;
esac
case $M_arg in
	RPKM|CPM|BPM|RPGC) 
		M_arg=${M_arg}
		NormName="_${M_arg}";;
	None)
		M_arg=${M_arg}
		NormName='';;
	*) 
		echo "Error value : -M argument must be in 'RPKM', 'CPM', 'BPM', 'RPGC' or 'None'"
		exit;;
esac
case $R_arg in
	true|TRUE|True|T) 
		R_arg='true';;
	false|FALSE|False|F)
		R_arg='false';;
	*) 
		echo "Error value : -R argument must be 'true' or 'false'"
		exit;;
esac

# Deal with options [-N|-F|-M|-R] and arguments [$1|$2|...]
shift $((OPTIND-1))

################################################################################################################
### ERRORS -----------------------------------------------------------------------------------------------------
################################################################################################################

if [ $# -eq 1 ] && [ $1 == "help" ]; then
	Help
	exit
elif [ $# -ne 1 ]; then
	# Error if no input directory is provided
	echo "Error synthax : please use following synthax"
	echo "      sh ${script_name} [options] <input_dir>"
	exit
elif [ $(ls $1/*${N_arg}*.bam 2>/dev/null | wc -l) -lt 1 ]; then
	# Error if provided directory is empty or does not exists
	echo 'Error : can not find files to align in provided directory. Please make sure the provided input directory exists, and contains matching .bam files.'
	exit
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

## BAM2BW - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 
# Set up parameters for SLURM ressources
TIME='0-00:30:00'; NODE='1'; TASK='1'; CPU='1'; MEM='3g'; QOS='quick'

# Create output directory
outdir="$(dirname ${1})"/${out_dir}
mkdir -p ${outdir}
# Precise to eliminate empty lists for the loop
shopt -s nullglob
for file in ${1}/*${N_arg}*.bam; do
	# Set variables for jobname
	current_file=`echo ${file} | sed -e "s@${1}\/@@g" | sed -e 's@\.bam@@g'`
	if [ $R_arg == 'true' ]; then
		# Remove suffix if R_arg is specified to 'true'
		current_file=`echo ${current_file} | sed -e "s@${N_arg}@@g"`
	fi

	# Define JOBNAME and COMMAND and launch job
	JOBNAME="BAM2${F_arg}_${current_file}"
	COMMAND="bamCoverage --normalizeUsing $M_arg --outFileFormat $F_arg \
	-b ${file} -o ${outdir}'/'${current_file}${NormName}'.'${file_ext}"
	Launch
done

