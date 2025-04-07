#!/bin/env bash

################################################################################################################
### HELP -------------------------------------------------------------------------------------------------------
################################################################################################################
script_name='7_WinPeaks.sh'

# Get user id for custom manual pathways
usr=`id | sed -e 's@).*@@g' | sed -e 's@.*(@@g'`

# Text font variables
END='\033[0m'
BOLD='\033[1m'
UDL='\033[4m'

# Show command manual
Help()
{
echo -e "${BOLD}####### WINPEAKS MANUAL #######${END}\n\n\
${BOLD}SYNTHAX${END}\n\
	sh ${script_name} [options] <input_dir> <fatsa_file> <gtf_file> <motif_file>\n\n\

${BOLD}DESCRIPTION${END}\n\
	Perform peaks annotation while looking for a specific given motif using HOMER.\n\
	It generates an annotated table with a column dedicated to presence or no of the motif.\n\

${BOLD}OPTIONS${END}\n\
	${BOLD}-N${END} ${UDL}suffix${END}, ${BOLD}N${END}amePattern\n\
		Define a suffix that input files must share to be considered. Allows to exclude unwanted peak files.\n\
		Default = _peaks\n\n\
	${BOLD}-F${END} ${UDL}extension${END}, ${BOLD}F${END}ormatInput\n\
		Define extension of files to use as input.\n\
		It usually corresponds to 'bed' or 'txt'.\n\
		Default = 'bed'\n\n\

${BOLD}ARGUMENTS${END}\n\
	${BOLD}<input_dir>${END}\n\
		Directory containing input peak files where look for motif.\n\
		It usually corresponds to 'HOMER/Peaks' or 'MACS2/Peaks'.\n\n\
	${BOLD}<fasta_file>${END}\n\
		Path to genome reference FASTA file.\n
		It can usually be downloaded from Ensembl genome browser.\n\n\
	${BOLD}<gtf_file>${END}\n\
		Path to GTF file containing annotation that correspond to provided FASTA file.\n
		It can usually be downloaded from Ensembl genome browser.\n\n\
	${BOLD}<motif_file>${END}\n\
		Path to .motif file containing DNA motif to look for in provided peak regions.\n\
		This type of file is generated by HOMER or available online.\n\n\

${BOLD}EXAMPLE USAGE${END}\n\
	sh ${script_name} ${BOLD}-N${END} '' ${BOLD}HOMER/Peaks ${usr}/Ref/Genome/Mus_musculus.GRCm39.dna_sm.primary_assembly.fa ${usr}/Ref/Genome/Mus_musculus.GRCm39.108.gtf ${usr}/Ref/Motifs/Factor.motif${END}\n"
}

################################################################################################################
### OPTIONS ----------------------------------------------------------------------------------------------------
################################################################################################################

# Set default values
N_arg="_peaks"
F_arg='bed'

# Change default values if another one is precised
while getopts ":N:F:" option; do
	case $option in
		N) # SUFFIX TO DISCRIMINATE FILES FOR INPUT
			N_arg=${OPTARG};;
		F) # FORMAT INPUT
			F_arg=${OPTARG};;
		\?) # Error
			echo "Error : invalid option"
			echo "      Allowed options are [-N|-F]"
			echo "      Enter 'sh ${script_name} help' for more details"
			exit;;
	esac
done

# Deal with options [-N|-F] and arguments [$1|$2|...]
shift $((OPTIND-1))

################################################################################################################
### ERRORS -----------------------------------------------------------------------------------------------------
################################################################################################################

if [ $# -eq 1 ] && [ $1 == "help" ]; then
	Help
	exit
elif [ $# -ne 4 ]; then
	# Error if inoccrect number of agruments is provided
	echo "378871312507674"
	echo "Something is missing..."
	exit
elif [ $(ls $1/*/*${N_arg}*.${F_arg} 2>/dev/null | wc -l) -lt 1 ]; then
	# Error if provided directory is empty or does not exists
	echo 'Error : can not find files in provided directory. Please make sure the provided directory exists, and contains .${F_arg} files.'
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

motif=`echo ${4} | sed -e 's@\.motif@@g' | sed -e 's@.*\/@@g'` 

## HOMER - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Set up parameters for SLURM ressources
TIME='0-00:30:00'; NODE='1'; TASK='1'; CPU='1'; MEM='5g'; QOS='quick'

for current_tag in ${1}/*; do
	# Precise to eliminate empty lists for the loop
	shopt -s nullglob
	for i in "${current_tag}"/*${N_arg}*.${F_arg}; do
		# Set variables for jobname
		current_file=`echo "${i}" | sed -e "s@.*\/@@g" | sed -e "s@\.${F_arg}@@g"`
		# Define JOBNAME and COMMAND and launch job
		JOBNAME="WinPeaks_${current_file}_${motif}"
		COMMAND="annotatePeaks.pl ${i} $2 -gtf $3 -m $4 > ${current_tag}/${current_file}_${motif}_location.txt"
		Launch 
	done
done
