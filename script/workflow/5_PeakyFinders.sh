#!/bin/env bash

################################################################################################################
### HELP -------------------------------------------------------------------------------------------------------
################################################################################################################
script_name='5_PeakyFinders.sh'

# Get user id for custom manual pathways
usr=`id | sed -e 's@).*@@g' | sed -e 's@.*(@@g'`

# Text font variables
END='\033[0m'
BOLD='\033[1m'
UDL='\033[4m'

# Show command manual
Help()
{
echo -e "${BOLD}####### PEAKYFINDERS MANUAL #######${END}\n\n\
${BOLD}SYNTHAX${END}\n\
	sh ${script_name} [options] <input_dir> <chrom_size>\n\n\

${BOLD}DESCRIPTION${END}\n\
	Perform peak calling from BAM files using HOMER or MACS2.\n\
	Peaks thus called are saved in a .txt or .narrowPeak file, sorted and then saved in .bed .bedgraph and .bw files. \n\
	It creates new folders './HOMER/Tags/<tag_name>' and './HOMER/Peaks/<tag_name>' or './MACS2/Peaks/<tag_name>' in which output files are stored.\n\n\

${BOLD}OPTIONS${END}\n\n\

${BOLD}Common Options${END}\n\
	${BOLD}-N${END} ${UDL}suffix${END}, ${BOLD}N${END}amePattern\n\
		Define a suffix that input files must share to be considered. Allows to exclude BAM files that are unfiltered or unwanted.\n\
		Default = '_filtered'\n\n\
	${BOLD}-U${END} ${UDL}toolName${END}, ${BOLD}U${END}sedTool\n\
		Define tool used for peak calling. Must be in 'HOMER' or 'MACS2'.\n\
		Default = 'HOMER'\n\n\

${BOLD}HOMER Options${END}\n\
	${BOLD}-S${END} ${UDL}size${END}, fragment${BOLD}S${END}ize\n\
		Define fragment size sequenced.\n\
		Default = auto\n\n\
	${BOLD}-M${END} ${UDL}style${END}, ${BOLD}M${END}ode\n\
		Precise mode (HOMER -style) to use when running script.\n\
		Must be in 'factor', 'histone', 'super', 'groseq', 'tss', 'dnase' or 'mC'.\n\
		Default = factor\n\n\
	${BOLD}-I${END} ${UDL}file${END}, ${BOLD}I${END}nputControl\n\
		Specify a CSV file containing 2 columns corresponding to 1)Tested BAM file; 2)Input BAM file. \n\
		Default = None\n\n\
	${BOLD}-F${END} ${UDL}threshold${END}, ${BOLD}F${END}oldEnrichmentVersusInput\n\
		NOT FUNCTIONNAL YET\n\
		Define required fold change of experimental data compared to input control to consider peaks.\n\
		Default = 4\n\n\
	${BOLD}-L${END} ${UDL}threshold${END}, ${BOLD}L${END}ocalFoldEnrichment\n\
		Define required fold change of a region compared to local signal (surrounding 10kb region) to consider peaks.\n\
		Default = 4\n\n\
	${BOLD}-C${END} ${UDL}threshold${END}, ${BOLD}C${END}lonalFoldEnrichment\n\
		Define maximal ratio for the number of unique positions containing tags in a peak relative to the expected number of unique positions given the total number of tags in the peak.\n\
		For MNase or other restriction enzyme digestion, should be setted to 0.\n\
		Default = 2\n\n\
	${BOLD}-T${END} ${UDL}threshold${END}, ${BOLD}T${END}agThreshold\n\
		Define required minimal tag value to consider peaks.\n\
		Default=2\n\n\

	For more details, please see HOMER manual \n\ 
	(http://homer.ucsd.edu/homer/ngs/peaks.html)\n\n\
    
${BOLD}MACS2 Options${END}\n\n\
	${BOLD}-G${END} ${UDL}size${END}, ${BOLD}G${END}enomSize\n\
		Effective genome size. Default human = 2.7e9 ; Default mouse : 1.87e9.\n\
		Default = 1.87e9\n\n\
	${BOLD}-F${END} ${UDL}format${END}, ${BOLD}F${END}ormat\n\
		Define file format used as input. Must be in 'BAM' or 'BED' for usual peak calling.\n\
		Could also be 'BEDGRAPH', in this case it will be run using macs2 bdgpeakcall function.\n\
		Default = BAM\n\n\
	${BOLD}-H${END} ${UDL}integer${END}, S${BOLD}h${END}ift\n\
		Value used to move cutting ends before applying ExtendSize parameter.\n\
		Default = 50\n\n\
	${BOLD}-S${END} ${UDL}integer${END}, ${BOLD}S${END}ize(Extend)\n\
		Extend reads by fixing fragment size to provided length.\n\
		If BEDGRAPH input files are used, it must be sat as fragment size.\n\
		Default = 100\n\n\

	For more details, please see MACS2 manual \n\n\

${BOLD}ARGUMENTS${END}\n\
	${BOLD}<input_dir>${END}\n\
		Directory containing BAM files to process.\n\
		It usually corresponds to 'Mapped/<model>/BAM'.\n\n\
	${BOLD}<chrom_size>${END}\n\
		Pathway to chromosome size file.\n\
		Could be downloaded on UCSC website (e.g. https://hgdownload.soe.ucsc.edu/goldenPath/mm39/bigZips/, 'mm39.chrom.sizes').\n\
		For HOMER usage, downloaded file have to be modified as following :\n\
			1) Remove 'chr' in front of chromosome names.\n\
			2) Remove everything before and after '_' for non-usual chromosomes names.\n\
			3) Replace 'v1' by '.1' in non-usual chromosme names.\n\
			4) Make sure entries are Tab separated.\n\n\
    
${BOLD}EXAMPLE USAGE${END}\n\
	sh ${script_name} ${BOLD}-U${END} 'HOMER' ${BOLD}-N${END} _filtered ${BOLD}-S${END} 50 ${BOLD}-M${END} dnase ${BOLD}-I${END} none ${BOLD}-F${END} none ${BOLD}-L${END} 4 ${BOLD}-C${END} 2 ${BOLD}Mapped/mm39/BAM ${usr}/Ref/Genome/mm39.chrom.sizes${END}\n\
		or\n\
	sh ${script_name} ${BOLD}-U${END} 'MACS2' ${BOLD}-N${END} _filtered ${BOLD}-G${END} 1.87e9 ${BOLD}-F${END} BAM ${BOLD}-H${END} 0 ${BOLD}-S${END} 50 ${BOLD}Mapped/mm39/BAM ${usr}/Ref/Genome/mm39.chrom.sizes${END}"
}

################################################################################################################
### OPTIONS ----------------------------------------------------------------------------------------------------
################################################################################################################

# Set default values
N_arg='_filtered'
U_arg='HOMER'

# Change default values if another one is precised
while getopts ":N:U:S:M:I:F:L:C:T:G:H:" option; do
	case $option in
		N) # NAME OF FILE (SUFFIX)
			N_arg=${OPTARG};;
		U) # USED TOOL FOR PEAK CALLING
			U_arg=${OPTARG}
			case ${U_arg} in
				HOMER|Homer|homer)
					U_arg='HOMER'
					S_arg='auto'
					M_arg='factor'
					I_arg='None' 
					F_arg=4 
					L_arg=4
					C_arg=2
					T_arg=2;;
				MACS2|Macs2|macs2)
					U_arg='MACS2'
					G_arg=1.87e9
					F_arg='BAM'
					H_arg=50
					S_arg=100;;
				*) 
					echo "Error value : -U argument must be 'HOMER' or 'MACS2'"
					exit;;
			esac;;
		S) # SIZE OF FRAGMENTS OR FRAGMENT SIZE EXTEND
			S_arg=${OPTARG};;
		M) # MODE TO RUN FIND PEAKS (STYLE)
			M_arg=${OPTARG};;
		I) # INPUT CONTROL (IgG)
			I_arg=${OPTARG};;
		F) # FOLD CHANGE THAN CONTROL THRESHOLD (IgG)
			F_arg=${OPTARG};;
		L) # LOCAL TAG FOLD CHANGE THRESHOLD
			L_arg=${OPTARG};;
		C) # CLONAL SIGNAL THRESHOLD
			C_arg=${OPTARG};;
		T) # TAG THRESHOLD
			T_arg=${OPTARG};;
		G) # MACS2 GENOME SIZE
			G_arg=${OPTARG};;
		H) # MACS2 SHIFT
			H_arg=${OPTARG};;
		\?) # Error
			echo "Error : invalid option"
			echo "      Allowed options are [-N|-U|-S|-M|-I|-F|-L|-C|-T|-G]"
			echo "      Enter 'sh ${script_name} help' for more details"
			exit;;
	esac
done

# Checking if provided option values are correct
case ${U_arg} in
	HOMER)
		file_ext='bam'
		case ${I_arg} in
			None|none|FALSE|False|false|F) 
				I_arg='None';;
			*) 
				I_arg=${I_arg};;
		esac;;
	MACS2)
		case ${F_arg} in
			BAM|Bam|bam) 
				F_arg='BAM'
				file_ext='bam'
				BDG='';;
			BED|Bed|bed)
				F_arg='BED'
				file_ext='bed'
				BDG='';;
			BEDGRAPH|Bedgraph|bedgraph|BedGraph|bdg|Bdg|BDG)
				F_arg='BEDGRAPH'
				file_ext='bedgraph'
				BDG='_BDG';;
			*) 
				echo "Error value : -F argument must be 'BAM', 'BED' or 'BEDGRAPH'"
				exit;;
		esac;;
esac

# Deal with options [-N|-U|-S|-M|-I|-F|-L|-C|-T|-G|-H] and arguments [$1|$2]
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
	echo "      sh ${script_name} [options] <input_dir> <chr_size_file>"
	exit
elif [ $(ls $1/*${N_arg}*.${file_ext} 2>/dev/null | wc -l) -lt 1 ]; then
	# Error if provided directory is empty or does not exists
	echo "Error : can not find files to process in provided directory. Please make sure the provided input directory exists, and contains matching .${file_ext} files."
	exit
elif [ ${U_arg} == 'HOMER' ] && [ ${I_arg} != "None" ] && [ $(ls ${I_arg} 2>/dev/null | wc -l) -lt 1 ]; then
	# Error if provided argument for I_arg is not found
	echo "Error : can not find provided input sheet file. Please make sure the provided file exists."
	exit
fi

################################################################################################################
### SCRIPT -----------------------------------------------------------------------------------------------------
################################################################################################################

## SETUP - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
module load samtools/1.15.1
module load bedtools/2.30.0
module load ucsc-bedgraphtobigwig/377

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

## HOMER - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
if [ ${U_arg} == 'HOMER' ]; then
	module load homer/4.11
	# Create Tags output directories
	mkdir -p HOMER/Tags
	# Initialize SampleSheet
	echo "ID,Tissue,Factor,Condition,Treatment,Replicate,bamReads,Peaks,PeakCaller" > HOMER/SampleSheet_HOMER.csv
	# For each matching BAM file in $input directory
	
	# Look if a CSV file for input BAM was specified
	if [ ${I_arg} == 'None' ]; then
		for file in ${1}/*${N_arg}*.bam; do
			# Genrate tag_name by removing pathway, suffix and .bam of read files
			current_tag=`echo ${file} | sed -e "s@${1}\/@@g" | sed -e 's@\.bam@@g'`
			# Create Peaks output directories
			outdir=HOMER/Peaks/${current_tag}
			mkdir -p ${outdir}

			# Set variables for the run :
			peaks_txt=${outdir}/${current_tag}_peaks.txt
			peaks_bed=${outdir}/${current_tag}_peaks.bed
			bedgraph=${outdir}/${current_tag}_peaks.bedgraph
			bigwig=${outdir}/${current_tag}_peaks.bw

			# Define JOBNAME and COMMAND and launch job
			JOBNAME="HOMER_${current_tag}"
			COMMAND="makeTagDirectory HOMER/Tags/${current_tag} ${file} -fragLength ${S_arg} -single \n\
			makeUCSCfile HOMER/Tags/${current_tag} -o auto \n\
			findPeaks HOMER/Tags/${current_tag} -style ${M_arg} \
			-o ${peaks_txt} -L ${L_arg} -C ${C_arg} \
			-tagThreshold ${T_arg} \n\
			grep -v '^#' ${peaks_txt} | awk -v OFS='\t' '{print \$2,\$3,\$4,\$1,\$8,\$5}' | bedtools sort > ${peaks_bed} \n\
			genomeCoverageBed -bga -i ${peaks_bed} -g ${2} | bedtools sort > ${bedgraph} \n\
			bedGraphToBigWig ${bedgraph} ${2} ${bigwig}"
			Launch
			# Append SampleSheet
			echo ",,,,,,${current_tag}.bam,${current_tag}_peaks.bed,bed" >> HOMER/SampleSheet_HOMER.csv
		done
	else
		sed 1d ${I_arg} | while IFS=',' read -r tested input; do
			# Remove carriage return
			tested=$(echo ${tested} | tr -d '\r')
			input=$(echo ${input} | tr -d '\r')
			# Initialize WAIT and JOBLIST to wait before running findPeaks
			WAIT=''
			JOBLIST='_'
			
			# Genrate tag_name by removing pathway, suffix and .bam of read files
			tested_tag=`echo ${tested} | sed -e "s@${1}\/@@g" | sed -e 's@\.bam@@g'`
			input_tag=`echo ${input} | sed -e "s@${1}\/@@g" | sed -e 's@\.bam@@g'`
			# Create Peaks output directories
			mkdir -p HOMER/Peaks/${tested_tag}_Input

			# Define JOBNAME and COMMAND and launch job while append JOBLIST
			# 1) makeTag for tested file
			JOBNAME="HOMER_makeTag_${tested_tag}"
			COMMAND="makeTagDirectory HOMER/Tags/${tested_tag} ${tested} -fragLength ${S_arg} -single \n\
			makeUCSCfile HOMER/Tags/${tested_tag} -o auto"
			JOBLIST=${JOBLIST}','${JOBNAME}
			Launch

			# 2) makeTag for input file
			JOBNAME="HOMER_makeTag_${input_tag}"
			COMMAND="makeTagDirectory HOMER/Tags/${input_tag} ${input} -fragLength ${S_arg} -single \n\
			makeUCSCfile HOMER/Tags/${input_tag} -o auto"
			JOBLIST=${JOBLIST}','${JOBNAME}
			Launch

			# 3) Peak Calling unsing both
			WAIT=`echo ${JOBLIST} | sed -e 's@_,@-hold_jid @'`

			# Set variables for the run :
			peaks_txt=HOMER/Peaks/${tested_tag}_Input/${tested_tag}_Input_peaks.txt
			peaks_bed=HOMER/Peaks/${tested_tag}_Input/${tested_tag}_Input_peaks.bed
			bedgraph=HOMER/Peaks/${tested_tag}_Input/${tested_tag}_Input_peaks.bedgraph
			bigwig=HOMER/Peaks/${tested_tag}_Input/${tested_tag}_Input_peaks.bw

			JOBNAME="HOMER_Input_${tested_tag}"
			COMMAND="findPeaks HOMER/Tags/${tested_tag} -style ${M_arg} \
			-o ${peaks_txt} -L ${L_arg} -C ${C_arg} \
			-tagThreshold ${T_arg} -i HOMER/Tags/${input_tag} -F ${F_arg} \n\
			grep -v '^#' ${peaks_txt} | awk -v OFS='\t' '{print \$2,\$3,\$4,\$1,\$8,\$5}' | bedtools sort > ${peaks_bed} \n\
			genomeCoverageBed -bga -i ${peaks_bed} -g ${2} | bedtools sort > ${bedgraph} \n\
			bedGraphToBigWig ${bedgraph} ${2} ${bigwig}"
			Launch
			# Append SampleSheet
			echo ",,,,,,${tested_tag}.bam,${tested_tag}_peaks.bed,bed" >> HOMER/SampleSheet_HOMER.csv
		done
	fi

## MACS2 - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
elif [ ${U_arg} == 'MACS2' ]; then
	module load gcc/11.2.0
	module load macs2/2.2.7.1
	# Create Tags output directories
	mkdir -p MACS2/Peaks
	# Initialize SampleSheet
	echo "ID,Tissue,Factor,Condition,Treatment,Replicate,bamReads,Peaks,PeakCaller" > MACS2/SampleSheet_MACS2${BDG}.csv

	# For each matching BAM file in $input directory
	for file in ${1}/*${N_arg}*.${file_ext}; do    
		# Define current tag
		current_tag=`echo ${file} | sed -e "s@${1}/@@g" | sed -e "s@\.${file_ext}@@g"`
		# Create output dir
		outdir=MACS2/Peaks/${current_tag}
		mkdir -p ${outdir}

		# Set variables for the run :
		narrrow_peak=${outdir}/${current_tag}_peaks.narrowPeak
		summits_bed=${outdir}/${current_tag}_summits.bed
		bedgraph=${outdir}/${current_tag}_summits.bedgraph
		bigwig=${outdir}/${current_tag}_summits.bw
	    
		# Define JOBNAME
		JOBNAME="MACS2${BDG}_${current_tag}"

		if [ ${F_arg} == 'BEDGRAPH' ]; then
			# Define COMMAND
			COMMAND="macs2 bdgpeakcall -i ${file} --cutoff 0.5 --min-length ${S_arg} \
			--max-gap ${S_arg} -o ${summits_bed}\n\
			genomeCoverageBed -bga -i ${summits_bed} -g ${2} | bedtools sort > ${bedgraph} \n\
			bedGraphToBigWig ${bedgraph} ${2} ${bigwig}"
		else
			# Define COMMAND
			COMMAND="macs2 callpeak -t ${file} --format ${F_arg} --gsize ${G_arg} \
			--nomodel --shift ${H_arg} --extsize ${S_arg} \
			-n ${current_tag} --outdir ${outdir} \n\
			genomeCoverageBed -bga -i ${summits_bed} -g ${2} | bedtools sort > ${bedgraph} \n\
			bedGraphToBigWig ${bedgraph} ${2} ${bigwig}"
		fi
	Launch
	# Append SampleSheet
	echo ",,,,,,${current_tag}.bam,${current_tag}_peaks.bed,bed" >> MACS2/SampleSheet_MACS2${BDG}.csv
	done
fi
