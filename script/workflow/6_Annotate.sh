#!/bin/env bash

################################################################################################################
### HELP -------------------------------------------------------------------------------------------------------
################################################################################################################
script_name='6_Annotate.sh'

# Get user id for custom manual pathways
usr=`id | sed -e 's@).*@@g' | sed -e 's@.*(@@g'`

# Text font variables
END='\033[0m'
BOLD='\033[1m'
UDL='\033[4m'

# Show command manual
Help()
{
echo -e "${BOLD}####### ANNOTATE MANUAL #######${END}\n\n\
${BOLD}SYNTHAX${END}\n\
	sh ${script_name} [options] <input_dir> <fasta_file> <gtf_file>\n\n\

${BOLD}DESCRIPTION${END}\n\
	Annotates peaks previously called by describing associated genome regions and genes, and performs motif enrichment research using HOMER.\n\n\
    
${BOLD}OPTIONS${END}\n\
	${BOLD}-N${END} ${UDL}suffix${END}, ${BOLD}N${END}amePattern\n\
		Define a suffix that input files must share to be considered. Allows to exclude unwanted peak files.\n\
		Default = ''\n\n\
	${BOLD}-R${END} ${UDL}size${END}, ${BOLD}R${END}egionSize\n\
		Define considered region size.\n\
		Default = 200 \n\n\
	${BOLD}-L${END} ${UDL}length${END}, ${BOLD}L${END}engthOfMotifs\n\
		Define lengths of motifs to look for during motif enrichment analysis.\n\
		Default = 8,10,12\n\n\
	${BOLD}-S${END} ${UDL}number${END}, ${BOLD}S${END}erieLength\n\
		Specifies the number of motifs of each length to find.\n\
		Default = 40\n\n\
	${BOLD}-A${END} ${UDL}boolean${END}, ${BOLD}A${END}nnotatePeaks\n\
		Specify whether peaks annotation have to be run.\n\
		Default = true\n\n\
	${BOLD}-M${END} ${UDL}boolean${END}, ${BOLD}M${END}otifFinding\n\
		Specify whether motifs enrichment analysis have to be run.\n\
		Default = true\n\n\
	${BOLD}-F${END} ${UDL}extension${END}, ${BOLD}F${END}ormatInput\n\
		Define extension of peak files to use as input.\n\
		Default = 'bed'\n\n\

${BOLD}ARGUMENTS${END}\n\
	${BOLD}<input_dir>${END}\n\
		Directory containing input peak files to annotate.\n\
		It usually corresponds to 'HOMER/Peaks' or 'MACS2/Peaks'.\n\n\
	${BOLD}<fasta_file>${END}\n\
		Path to genome reference FASTA file.\n
		It can usually be downloaded from Ensembl genome browser.\n\n\
	${BOLD}<gtf_file>${END}\n\
		Path to GTF file containing annotation that corresponds to provided FASTA file.\n
		It can usually be downloaded from Ensembl genome browser.\n\n\

${BOLD}EXAMPLE USAGE${END}\n\
	sh ${script_name} ${BOLD}-N${END} _peaks ${BOLD}-R${END} 200 ${BOLD}-L${END} '8,10,12' ${BOLD}-A${END} true ${BOLD}-M${END} true ${BOLD}HOMER/Peaks ${usr}/Ref/Genome/Mus_musculus.GRCm39.dna_sm.primary_assembly.fa ${usr}/Ref/Genome/Mus_musculus.GRCm39.108.gtf${END}\n"
}

################################################################################################################
### OPTIONS ----------------------------------------------------------------------------------------------------
################################################################################################################

# Set default values
N_arg=''
R_arg=200
L_arg='8,10,12'
S_arg=40
A_arg=true
M_arg=true
F_arg='bed'

# Change default values if another one is precised
while getopts ":N:R:L:S:A:M:F:" option; do
	case $option in
		N) # SUFFIX TO DISCRIMINATE FILES FOR INPUT
			N_arg=${OPTARG};;
		R) # REGION SIZE
			R_arg=${OPTARG};;
		L) # MOTIF LENGTH
			L_arg=${OPTARG};;
		S) # FORMAT INPUT
			S_arg=${OPTARG};;
		A) # ANNOTATE PEAKS
			A_arg=${OPTARG};;
		M) # SEARCH MOTIFS
			M_arg=${OPTARG};;
		F) # FORMAT INPUT
			F_arg=${OPTARG};;
		\?) # Error
			echo "Error : invalid option"
			echo "      Allowed options are [-N|-R|-L|-S|-A|-M|-F]"
			echo "      Enter 'sh ${script_name} help' for more details"
			exit;;
	esac
done

# Checking if provided option values are correct
case $A_arg in
	true|TRUE|True|T) 
		A_arg='true';;
	false|FALSE|False|F)
		A_arg='false';;
	*) 
		echo "Error value : -A argument must be 'true' or 'false'"
		exit;;
esac
case $M_arg in
	true|TRUE|True|T) 
		M_arg='true';;
	false|FALSE|False|F)
		M_arg='false';;
	*) 
		echo "Error value : -M argument must be 'true' or 'false'"
		exit;;
esac

# Deal with options [-N|-R|-L|-A|-M|-F|-S] and arguments [$1|$2|...]
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
	echo "      sh ${script_name} [options] <input_dir> <fasta_file> <gtf_file>"
	exit
elif [ $(ls $1/*/*${N_arg}*.${F_arg} 2>/dev/null | wc -l) -lt 1 ]; then
	# Error if provided directory is empty or does not exists
	echo -e "Error : can not find files in provided directory. Please make sure the provided directory exists, and contains .${F_arg} files."
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

## HOMER - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
for current_tag in ${1}/*; do
	# Precise to eliminate empty lists for the loop
	shopt -s nullglob
	for i in "${current_tag}"/*${N_arg}*.${F_arg}; do
		# Set variables for jobname
		current_file=`echo "${i}" | sed -e "s@.*\/@@g" | sed -e "s@\.${F_arg}@@g"`
		# Define JOBNAME and COMMAND and launch job
		if [ ${A_arg} == 'true' ]; then
			# Set up parameters for SLURM ressources
			TIME='0-01:30:00'; NODE='1'; TASK='1'; CPU='1'; MEM='10g'; QOS='quick'
			JOBNAME=AnnotatePeaks_"${current_file}"
			COMMAND="annotatePeaks.pl "${i}" ${2} -gtf ${3} > "${current_tag}"/"${current_file}"_annotated.txt"
			Launch
		fi
		if [ ${M_arg} == 'true' ]; then
			# Set up parameters for SLURM ressources
			TIME='0-05:00:00'; NODE='1'; TASK='1'; CPU='1'; MEM='5g'; QOS='short'
			JOBNAME=AnnotateMotifs_"${current_file}"
			COMMAND="findMotifsGenome.pl "${i}" ${2} "${current_tag}" -size ${R_arg} -len ${L_arg} -S ${S_arg}"
			Launch
		fi
	done
done
