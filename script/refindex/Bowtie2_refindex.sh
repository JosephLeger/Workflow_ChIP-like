#!/bin/env bash

################################################################################################################
### HELP -------------------------------------------------------------------------------------------------------
################################################################################################################
script_name='Bowtie2_refindex.sh'

# Get user id for custom manual pathways
usr=`id | sed -e 's@).*@@g' | sed -e 's@.*(@@g'`

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

## BOWTIE2 INDEX - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Set up parameters for SLURM ressources
TIME='0-00:30:00'; NODE='1'; TASK='1'; CPU='1'; MEM='10g'; QOS='quick'

# Define JOBNAME and COMMAND and launch job
JOBNAME="Bowtie2_RefIndex_${2}"
COMMAND="bowtie2-build -f ${1} ${2}"
Launch
