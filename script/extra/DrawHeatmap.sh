#!/bin/env bash

################################################################################################################
### HELP -------------------------------------------------------------------------------------------------------
################################################################################################################
script_name='DrawHeatmap.sh'

# Get user id for custom manual pathways
usr=`id | sed -e 's@).*@@g' | sed -e 's@.*(@@g'`

# Text font variables
END='\033[0m'
BOLD='\033[1m'
UDL='\033[4m'

# Show command manual
Help()
{
echo -e "${BOLD}####### INDEXBAM MANUAL #######${END}\n\n\
${BOLD}SYNTHAX${END}\n\
	sh ${script_name} [options] <output_dir> <BED> <BW_1> <...>\n\n\

${BOLD}DESCRIPTION${END}\n\
	Draw heatmap based on a provided BED file containing regions.

${BOLD}OPTIONS${END}\n\
	${BOLD}-O${END} ${UDL}string${END}, ${BOLD}O${END}utputFilename\n\
		Define output filename used for matrix and heatmap generation.\n\
		Default = 'Matrix_Heatmap'\n\n\
	${BOLD}-S${END} ${UDL}boolean${END}, ${BOLD}S${END}ortBED\n\
		Define whether BED files have to be sorted using Bedtools prior matrix computing.\n\
		Default = false\n\n\
	${BOLD}-K${END} ${UDL}integer${END}, ${BOLD}K${END}meansNumber\n\
		Define number of cluster to use for K-Means clustering.\n\
		If 'custom' is specified, clustering will be perfomred for regions separated in multiple BED files.\n\
		In that case, <BED> argument must be the path of the directory containing these BED files.\n\
		Default = 1\n\n\
	${BOLD}-Z${END} ${UDL}string${END}, ${BOLD}Z${END}min-max\n\
		Define minimum and maximum value of intensities for heatmap.\n\
		Default = '0,50'\n\n\
	${BOLD}-T${END} ${UDL}string${END}, Plo${BOLD}T${END}Size\n\
		Define plot Height and Width in cm.\n\
		Height must be between a range 3-100 and Width in a range 1-100.\n\
		Default = '50,8'\n\n\

${BOLD}ARGUMENTS${END}\n\
	${BOLD}<output_dir>${END}\n\
		Directory to use for saving generated output files.\n\n\
	${BOLD}<BED>${END}\n\
		Depending on options, must be :
		1) BED file containing regions to show.\n\
		\n\n\
	${BOLD}<BW>${END}\n\
		BW file(s) deriving from BAM files to show.\n\
		It could be multiple files (BW1.bw BW2.bw BW3.bw) or a matching pattern (BW*.bw) \n\n\
   		
${BOLD}EXAMPLE USAGE${END}\n\
	sh ${script_name} ${BOLD}-O${END} 'MatrixHeatmap' ${BOLD}-S${END} true ${BOLD}-K${END} 1 ${BOLD}outdir peaks.bed regions_*.bw${END}\n"
}

################################################################################################################
### OPTIONS ----------------------------------------------------------------------------------------------------
################################################################################################################

# Set default values
O_arg='Matrix_Heatmap'
S_arg='false'
K_arg=1
Z_arg='0,50'
T_arg='50,8'

# Change default values if another one is precised
while getopts ":O:S:K:Z:T:" option; do
	case $option in
		O) # OUTPUT FILENAME
			O_arg=${OPTARG};;
		S) # SORT BED FILE
			S_arg=${OPTARG};;
		K) # KMEANS NUMBER
			K_arg=${OPTARG};;
		Z) # COLOR INTENSITIE
			Z_arg=${OPTARG};;
		T) # PLOT SIZE
			T_arg=${OPTARG};;
		\?) # Error
			echo "Error : invalid option"
			echo "      Allowed options are [-O|-S|-K|-Z|-T]"
			echo "      Enter 'sh ${script_name} help' for more details"
			exit;;
	esac
done

# Checking if provided option values are correct
case $S_arg in
	TRUE|True|true|T|t) 
		S_arg='true'
		newsuffix='_sorted';;
	FALSE|False|false|F|f) 
		S_arg='false'
		newsuffix='';;
	*) 
		echo "Error value : -S argument must be 'true' or 'false'"
		exit;;
esac 

# Subset parameter lists
Z1_arg="$(cut -d',' -f1 <<<"$Z_arg")"
Z2_arg="$(cut -d',' -f2 <<<"$Z_arg")"

T1_arg="$(cut -d',' -f1 <<<"$T_arg")"
T2_arg="$(cut -d',' -f2 <<<"$T_arg")"

# Deal with options [-O|-S|-K] and arguments [$1|$2|...]
shift $((OPTIND-1))

# Prepare for custom or Kmeans clustering
case $K_arg in
	[0-9]*) 
		K_arg="--kmeans ${K_arg} "
		bedfiles=${2};;
	CUSTOM|Custom|custom) 
		K_arg=''
		bedfiles=${2}/*.bed;;
	*) 
		echo "Error value : -K argument must be 'custom' or an integer"
		exit;;
esac

################################################################################################################
### ERRORS -----------------------------------------------------------------------------------------------------
################################################################################################################

if [ $# -eq 1 ] && [ $1 == "help" ]; then
	Help
	exit
elif [ $# -lt 3 ]; then
	# Error if arguments are missing
	echo "Error synthax : please use following synthax"
	echo "      sh ${script_name} [options] <output_dir> <BED> <BW>"
	exit
elif [ ! -d "${1}" ]; then
	# Error if provided output directory does not exist
	echo 'Error : can not provided output directory. Please make sure the provided output directory exists.'
	exit
elif [ ${K_arg} == '' ]; then
	if [ $(ls ${2}/*.bed 2>/dev/null | wc -l) -lt 1 ]; then
		# Error if -K custom is specified and provided directory does not exist or is empty
		echo 'Error : can not find files in provided directory. Please make sure the provided input directory exists, and contains .bed files.'
		exit
  	fi
fi

################################################################################################################
### SCRIPT -----------------------------------------------------------------------------------------------------
################################################################################################################

## SETUP - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
module load deeptools
module load bedtools/2.30.0

# Generate REPORT
echo '#' >> ./0K_REPORT.txt
date >> ./0K_REPORT.txt

Launch()
{
# Launch COMMAND and save report
echo -e "#$ -V \n#$ -cwd \n#$ -S /bin/bash \n"${COMMAND} | qsub -N ${JOBNAME} ${WAIT}
echo -e ${JOBNAME} >> ./0K_REPORT.txt
echo -e ${COMMAND} | sed 's@^@   \| @' >> ./0K_REPORT.txt
}
WAIT=''

## SORT BED - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 

if [ ${S_arg} == 'true' ]; then
	# Precise to eliminate empty lists for the loop
	shopt -s nullglob
	for b in ${bedfiles}; do	

		# Set variables for jobname
		filename=`echo ${b} | sed -e 's@.*\/@@g'`
		output=`echo ${b} | sed -e 's@\.bed@_sorted\.bed@g'`

		# Define JOBNAME and COMMAND considering WAIT
		JOBNAME="SortBed_${filename}"
		COMMAND="rm -f ${output}\n\
		touch ${output}\n\
		bedtools sort -i ${b} > ${output}"
		Launch
		WAIT=`echo "-hold_jid ${JOBNAME}"`
	done
	sorted_bedfiles=`echo ${bedfiles} | sed -e 's@\.bed@_sorted\.bed@g'`
else
	sorted_bedfiles=${bedfiles}
fi

## MATRIX COMPUTATION AND HEATMAP- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

# Set provided BW files as a single string
bw_list=''
for arg in ${@:3}; do
	bw_list="${bw_list} ${arg}"
done

# Define JOBNAME and COMMAND considering WAIT
JOBNAME="BaseHeatmap_${O_arg}"
COMMAND="computeMatrix reference-point --referencePoint center \
-b 1000 -a 1000 \
-R ${sorted_bedfiles} \
-S ${bw_list} \
--skipZeros \
-o ${1}'/'${O_arg}'.gz' \
-p 6 --missingDataAsZero --sortRegions keep \
--outFileSortedRegions $1'/'${O_arg}'.bed'\
\n\
plotHeatmap -m $1'/'${O_arg}'.gz' \
--colorList white,blue \
--heatmapHeight ${T1_arg} --heatmapWidth ${T2_arg} \
-out $1'/'${O_arg}'.png' \
--whatToShow 'plot, heatmap and colorbar' \
--zMin ${Z1_arg} --zMax ${Z2_arg} \
${K_arg}"
Launch
