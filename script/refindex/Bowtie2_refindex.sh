#!/bin/env bash

################################################################################################################
### HELP -------------------------------------------------------------------------------------------------------
################################################################################################################
script_name='Bowtie2_refindex.sh'

# Text font variabes
END='\033[0m'
BOLD='\033[1m'
UDL='\033[4m'

Help()
{
echo -e "${BOLD}####### BOWTIE2_REFINDEX MANUAL #######${END}\n\n\
${BOLD}SYNTHAX${END}\n\
    sh ${script_name} <fasta_file> <ref_name>\n\n\

${BOLD}DESCRIPTION${END}\n\
    Index reference genome from FASTA file for Bowtie2.\n\n\

${BOLD}ARGUMENTS${END}\n\
    ${BOLD}<fasta_file>${END}\n\
        Path to FASTA file to use for making reference.\n
        It can usually be downloaded from Ensembl genome browser.\n\n\
    ${BOLD}<ref_name>${END}\n\
        Define a name for making refseq. It is used as prefix for generated files, and will be important for calling refseq during alignment step.\n\n\

${BOLD}EXAMPLE USAGE${END}\n\
    sh ${script_name} ${BOLD}../Ref/Genome/Mus_musculus.GRCm39.dna_sm.primary_assembly.fa mm39${END}\n"
}

################################################################################################################
### ERRORS -----------------------------------------------------------------------------------------------------
################################################################################################################

if [ $# -eq 1 ] && [ $1 == "help" ]; then
    Help
    exit
elif [ $# -ne 2 ]; then
    # Error if inoccrect number of agruments is provided
    echo "Error synthax : please use following synthax"
    echo "       sh ${script_name} <fasta_file> <gtf_file>"
    exit
elif [ ! -f "$1" ]; then
    echo "Error : FASTA file not found. Please make sure provided pathway is correct."
    exit
fi

################################################################################################################
### SCRIPT -----------------------------------------------------------------------------------------------------
################################################################################################################

## SETUP - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
module load bowtie2/2.5.1

echo -e "#$ -V \n#$ -cwd \n#$ -S /bin/bash \n\
bowtie2-build -f $1 $2" | qsub -N STAR_RefIndex
