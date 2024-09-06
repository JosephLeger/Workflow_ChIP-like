#!/bin/env bash

################################################################################################################
### HELP -------------------------------------------------------------------------------------------------------
################################################################################################################
script_name='BaseHeatmap.sh'

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
		Default = 1\n\n\

${BOLD}ARGUMENTS${END}\n\
	${BOLD}<output_dir>${END}\n\
		Directory to use for saving generated output files.\n\n\
	${BOLD}<BED>${END}\n\
		BED file containing regions to show.\n\n\
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

# Change default values if another one is precised
while getopts ":O:S:K:" option; do
	case $option in
		O) # OUTPUT FILENAME
			O_arg=${OPTARG};;
		S) # SORT BED FILE
			S_arg=${OPTARG};;
		K) # KMEANS NUMBER
			K_arg=${OPTARG};;
		\?) # Error
			echo "Error : invalid option"
			echo "      Allowed options are [-O|-S|-K]"
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

# Deal with options [-O|-S|-K] and arguments [$1|$2|...]
shift $((OPTIND-1))

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

#
# sh <scriptname> [options] outdir bedfile bw_file1, bw_file2, ...
# -O "output_filename" -S "sort?" -K "n_kmeans"

## SORT BED - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 
if [ ${S_arg} == 'true' ]; then
	# Set variables for jobname
	filename=`echo ${2} | sed -e 's@.*\/@@g'`
	output=`echo ${2} | sed -e 's@\.bed@_sorted\.bed@g'`

	# Define JOBNAME and COMMAND considering WAIT
	JOBNAME="SortBed_${filename}"
	COMMAND="rm -f ${output}\n\
	touch ${output}\n\
	bedtools sort -i ${2} > ${output}"
	Launch
	WAIT=`echo "-hold_jid ${JOBNAME}"`
fi

## MATRIX COMPUTATION AND HEATMAP- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

# Set input BED filename
input=`echo ${2} | sed -e 's@\.bed@${newsuffix}\.bed@g'`

# Set provided BW files as a single string
bw_list=''
for arg in ${@:3}; do
	bw_list="${bw_list} ${arg}"
done

# Define JOBNAME and COMMAND considering WAIT
JOBNAME="BaseHeatmap_${O_arg}"
COMMAND="computeMatrix reference-point --referencePoint center \
-b 1000 -a 1000 \
-R ${input} \
-S ${bw_list} \
--skipZeros \
-o ${1}'/'${O_arg}'.gz' \
-p 6 --missingDataAsZero --sortRegions keep \
--outFileSortedRegions $1'/'${O_arg}'.bed'\
\n\
plotHeatmap -m $1'/'${O_arg}'.gz' \
--colorList white,blue \
--heatmapHeight 25 --heatmapWidth 3 \
-out $1'/'${O_arg}'.png' \
--whatToShow 'heatmap and colorbar' \
--kmeans ${K_arg} \
--zMin 0 --zMax 30"
Launch





