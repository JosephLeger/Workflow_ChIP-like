#!/bin/env bash

################################################################################################################
### HELP -------------------------------------------------------------------------------------------------------
################################################################################################################

# Get user id for custom manual pathways
usr=`id | sed -e 's@).*@@g' | sed -e 's@.*(@@g'`

# Text font variabes
END='\033[0m'
BOLD='\033[1m'
UDL='\033[4m'

# Show command manual
Help()
{
echo -e "${BOLD}####### ANNOTATE MANUAL #######${END}\n\n\
${BOLD}SYNTHAX${END}\n\
    sh Annotate.sh [options] <input_dir> <fasta_file> <gtf_file>\n\n\

${BOLD}DESCRIPTION${END}\n\
    Annotates peaks previously called by describing associated genome regions and genes, and performs motif enrichment research.\n\n\
    
${BOLD}OPTIONS${END}\n\
    ${BOLD}-N${END} ${UDL}suffix${END}, ${BOLD}N${END}amePattern\n\
        Define a suffix that input files must share to be considered. Allows to exclude unwanted peak files.\n\
        Default = _peaks\n\n\
    ${BOLD}-R${END} ${UDL}size${END}, ${BOLD}R${END}egionSize\n\
        Define \n\
        Default = 200 \n\n\
    ${BOLD}-L${END} ${UDL}length${END}, ${BOLD}Length${END}OfMotifs\n\
        Define lengths of motifs to look for during motif enrichment analysis.\n\
        Default = 8,10,12\n\n\
    ${BOLD}-A${END} ${UDL}boolean${END}, ${BOLD}A${END}nnotatePeaks\n\
        Specify whether peak annotation have to be run.\n\
        Default = true\n\n\
    ${BOLD}-M${END} ${UDL}boolean${END}, ${BOLD}M${END}otifFinding\n\
        Specify whether motif enrichment analysis have to be run.\n\
        Default = true\n\n\
    ${BOLD}-F${END} ${UDL}extension${END}, ${BOLD}F${END}ormatInput\n\
        Define extension of files to use as input.\n\
        Default = 'bed'\n\n\

${BOLD}ARGUMENTS${END}\n\
    ${BOLD}<input_dir>${END}\n\
        Directory containing .bam files to process.\n\
        It usually corresponds to 'Mapped/<model>/BAM'.\n\n\
    ${BOLD}<fasta_file>${END}\n\
        Path to FASTA genome reference file.\n
        It can usually be downloaded from Ensembl genome browser.\n\n\
    ${BOLD}<gtf_file>${END}\n\
        Path to GTF file containing annotation that correspond to provided FASTA file.\n
        It can usually be downloaded from Ensembl genome browser.\n\n\

${BOLD}EXAMPLE USAGE${END}\n\
    sh 8_Annotate.sh ${BOLD}-N${END} _peaks ${BOLD}-R${END} 200 ${BOLD}-L${END} '8,10,12' ${BOLD}-A${END} true ${BOLD}-M${END} true ${BOLD}HOMER/Peaks /LAB-DATA/BiRD/users/jleger/Ref/Genome/Mus_musculus.GRCm39.dna_sm.primary_assembly.fa /LAB-DATA/BiRD/users/jleger/Ref/Genome/Mus_musculus.GRCm39.108.gtf${END}\n"
}

################################################################################################################
### OPTIONS ----------------------------------------------------------------------------------------------------
################################################################################################################

# Set default values
N_arg="_peaks"
R_arg=200
L_arg='8,10,12'
A_arg=true
M_arg=true
F_arg='bed'

# Change default values if another one is precised
while getopts ":N:R:L:A:M:F:" option; do
    case $option in
        N) # SUFFIX TO DISCRIMINATE FILES FOR INPUT
            N_arg=${OPTARG};;
        R) # REGION SIZE
            R_arg=${OPTARG};;
        L) # MOTIF LENGTH
            L_arg=${OPTARG};;
        A) # ANNOTATE PEAKS
            A_arg=${OPTARG};;
        M) # SEARCH MOTIFS
            M_arg=${OPTARG};;
        F) # FORMAT INPUT
            F_arg=${OPTARG};;
        \?) # Error
            echo "Error : invalid option"
            echo "      Allowed options are [-N|-R|-L|-A|-M|-F]"
            echo "      Enter sh MarkDuplicates.sh help for more details"
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

# Deal with options [-N|-R|-L|-A|-M] and arguments [$1|$2|...]
shift $((OPTIND-1))

################################################################################################################
### ERRORS -----------------------------------------------------------------------------------------------------
################################################################################################################

if [ $# -eq 1 ] && [ $1 == "help" ]; then
    Help
    exit
elif [ $# != 3 ]; then
    # Error if no input directory is provided
    echo 'Error synthax : please use following synthax'
    echo '      sh Annotate.sh [options] <input_dir> <fasta_file> <gtf_file>'
    exit
fi

################################################################################################################
### SCRIPT -----------------------------------------------------------------------------------------------------
################################################################################################################

module load homer/4.11
module load samtools/1.15.1

#annotatePeaks.pl in.bed Mus_musculus.GRCm39.dna_sm.primary_assembly.fa -gtf Mus_musculus.GRCm39.108.gtf > out.txt
#findMotifsGenome.pl in.bed Mus_musculus.GRCm39.dna_sm.primary_assembly.fa out -size 200 -len 10

# For DNAse
# sh 8_Annotate.sh -N _peaks -R 200 -L '8,10,12' -A true -M true HOMER/Peaks /SCRATCH-BIRD/users/jleger/Data/Ref/Genome/Mus_musculus.GRCm39.dna_sm.primary_assembly.fa /SCRATCH-BIRD/users/jleger/Data/Ref/Genome/$
# For ChIC
# sh 8_Annotate.sh -N _peaks -R 1000 -L '8,10,12' -A true -M true HOMER/Peaks /SCRATCH-BIRD/users/jleger/Data/Ref/Genome/Mus_musculus.GRCm39.dna_sm.primary_assembly.fa /SCRATCH-BIRD/users/jleger/Data/Ref/Genome$

for current_tag in ${1}/*; do
    # Precise to eliminate empty lists for the loop
    shopt -s nullglob
    for i in "${current_tag}"/*${N_arg}*.${F_arg}; do
        # Set variables for jobname
        current_file=`echo "${i}" | sed -e "s@.*\/@@g" | sed -e "s@\.${F_arg}@@g"`
        if [ ${A_arg} == 'true' ]; then
            # Launch annotation as a qsub
            echo -e "#$ -V \n#$ -cwd \n#$ -S /bin/bash \n\
            annotatePeaks.pl ${i} ${2} -gtf ${3} > ${current_tag}/${current_file}_annotated.txt" | qsub -N AnnotatePeaks_"${current_file}"
        fi

        if [ ${M_arg} == 'true' ]; then
            # Launch motif finding as a qsub
            echo -e "#$ -V \n#$ -cwd \n#$ -S /bin/bash \n\
            findMotifsGenome.pl ${i} ${2} ${current_tag} -size ${R_arg} -len ${L_arg} -S 40" | qsub -N AnnotateMotifs_"${current_file}"
        fi
    done
done

