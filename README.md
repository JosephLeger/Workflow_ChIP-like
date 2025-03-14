# Workflow description

This workflow was designed to perform analyzes of chromatin accessibility or ChIP-like data, from FASTQ files to peak calling and motif enrichment analysis.  
  
It is deliberately not automated, and requires launching the scripts manually one after the other, keeping full user control and allowing custom options, whilst retaining some standardization and repeatability. Therefore, it is well suited to users who want to perform analyzes step by step by taking the time to understand the results of one step before launching the next one, and possibly change the parameters accordingly.

    
<p align="center">
<img src="https://github.com/JosephLeger/Workflow_ChIP-like/blob/main/img/pipeline.jpg"  width="67%" height="67%">
</p>

### Steps Summary
0. **Preparing the reference :** To perform mapping to reference genome, it must be indexed for **Bowtie2** usage first. To do so, it requires reference genome (FASTA file) available for download in Ensembl.org gateway. This step has to be performed only the first time you use Bowtie2 for the current genome RefSeq.  

1. **Quality Check :** Quality of each FASTQ file is assessed using **FastQC**. A quality control report per file is then obtained, providing information on the quality of the bases, the length of the reads, the presence of adapters, etc. To make it easier to visualize the results, all reports are then pooled and analyzed simultaneously using **MultiQC**.

2. **Trimming :** According to the conclusions drawn from the quality control of the reads, a trimming step is often necessary. This step makes it possible to clean the reads, for example by eliminating sequences enriched in adapters, or by trimming poor quality bases at the ends of the reads. For this, **Trimmomatic** needs to be provided with the adapter sequences used for sequencing if an enrichment has been detected. Trimming script includes the optional use of **Clumpify** (bbmap) to remove duplicated reads at FASTQ stage and to optimize file organization.  
A quality control is carried out on the FASTQ files resulting from trimming to ensure that the quality obtained is satisfactory.

3. **Alignment to the genome :** Clean FASTQ files are then mapped to the previously indexed reference genome in order to identify the regions from which the reads come. This workflow uses **Bowtie2**, a widely used tool for read mapping, to generate sorted BAM files.  
A quality control is carried out on the BAM files resulting from alignment to ensure reads were correctly mapped.  

4. **Filtering and Indexing BAM :** If it hasn't already been done duplicated reads are removed, and reads with low alignment scores are filtered out using **Picard** and **SamTools**. Resulting BAM files are then indexed for following steps.  

5. **Peak Calling :** To identify notable regions, aligned reads are then converted to peaks. This workflow provides two different widely used peak callers, **MACS2** and **HOMER**. Both will generate specific peak files, that are then converted into BED, BEDGRAPH and BIGWIG formats for following steps or visualization.  

6. **Peak Annotation :** Previously called peaks are associated with the gene corresponding to their genomic region using **HOMER**. In parallel, motif enrichment analysis can be launched, in order to identify known or *de novo* transcription factor specific motifs.  

7. **Association Motif-Peaks :** This extra step can be launched to identify potential interactions between a factor and genomic regions. From peak calling results and a provided motif file, **HOMER** will generate a fully annotated peak table adding information to the peaks near which the motif appears in an additional column.  

*Supplementary scripts are also available in ./scripts/extra folder of this repository.*

# Initialization and recommandations
### Scripts
All required scripts are available in the script folder in this directory.  
To get more information about using these scripts, enter the command ```sh <script.sh> help```.  
  
### Environments
The workflow is encoded in Shell language and is supposed to be launched under a Linux environment.  
Moreover, it was written to be used on a computing cluster using **Sun Grid Engine (SGE)** with tools already pre-installed in the form of modules. Modules are so loaded using `module load <tool_name>` command. If you use manually installed environments, simply replace module loading in script section by the environment activation command.  
All script files launch tasks as **qsub** task submission. To successfully complete the workflow, wait for all the jobs in a step to be completed before launching the next one.  
 
### Requirements
```
Name                        Version
fastqc                      0.11.9
multiqc                     1.13
trimmomatic                 0.39
bbmap                       39.00
bowtie2                     2.5.1
samtools                    1.15.1
picard                      2.23.5
bedtools                    2.30.0
ucsc-bedgraphtobigwig       377
gcc                         11.2.0
macs2                       2.2.7.1
homer                       4.11
```

### Project directory
To start the workflow, create a new directory for the project and put previously downloaded scripts inside. Create a 'Raw' subdirectory and put all the raw FASTQ files inside.  
Raw FASTQ files must be compressed in '.fq.gz' or '.fastq.gz' format. If it is not the case, you need to compress them using ```gzip Raw/*.fastq```.  
  
For the following example, this type of folder tree is used :  
  
<p align="left">
<img src="https://github.com/JosephLeger/Workflow_ChIP-like/blob/main/img/paths.png"  width="55%" height="55%">
</p>
  
# Workflow Step by Step
### 0. Preparing the reference
This step only needs to be carried out during the first alignment. The genome once indexed can be reused as a reference for subsequent alignments.  
First, you need to download reference genome FASTA file and annotaion GTF file in the Genome folder.
```
# Example with mouse genome from Ensembl.org
wget https://ftp.ensembl.org/pub/release-108/fasta/mus_musculus/dna/Mus_musculus.GRCm39.dna_sm.primary_assembly.fa.gz
wget https://ftp.ensembl.org/pub/release-108/gtf/mus_musculus/Mus_musculus.GRCm39.108.gtf.gz
```
Then, create a directory for the reference and use provided scripts from the ./script/refindex folder of this repository.  

Syntax : ```sh Bowtie2_refindex.sh <FASTA> <build_name>```  
```bash
sh Bowtie2_refindex.sh ../Genome/Mus_musculus.GRCm39.dna_sm.primary_assembly.fa.gz mm39
```
*Once indexing is done, every following steps are performed directly in the project directory.*  

### 1. Quality Check
Syntax : ```sh 1_QC.sh <input_dir>```  
```bash
sh 1_QC.sh Raw
```
Pooled results are available in ./QC/MultiQC/QC_Raw_MultiQC.html file.  

### 2. Trimming
Provided trimming script allows several options using either **Trimmomatic** (```-U Trimmomatic```), **Clumpify** (```-U Clumpify```) or both (```-U Both```).  
#### Trimmomatic options
* **-S** (Slingdingwindow) : Perform a sliding window trimming, cutting once the average quality within the window falls below a threshold.  
* **-L** (Leading) : Remove low quality bases from the beginning.  
* **-T** (Trailing) : Remove low quality bases from the end.   
* **-M** (Minlen) : This module removes reads that fall below the specified minimal length.  
* **-I** (Illuminaclip) : Cuts adapters and other Illumina-specific sequences present in the reads.
  
*For more details, please read [Trimmomatic Manual](http://www.usadellab.org/cms/uploads/supplementary/Trimmomatic/TrimmomaticManual_V0.32.pdf).*  

#### Clumpify option
* **-D** (Deduplicate) : Remove duplicated reads.  
  
*Note: Clumpify will also optimize file organization, reducing file size.*  
  
Syntax : ```sh 2_Trim.sh [options] <SE|PE> <input_dir>```  
```bash
sh 2_Trim.sh -U 'Both' -S 4:15 -L 5 -T 5 -M 36 -I ../Ref/Trimmomatic/TruSeq3-SE_NexteraPE-PE.fa:2:30:10 -D True SE Raw
```
*Note : after trimming, launch QC step again to ensure all adapters and low quality bases have been correctly removed.*

### 3. Alignment to genome
Syntax : ```sh 3_Bowtie2.sh [options] <SE|PE> <input_dir> <refindex>```   
```bash
sh 3_Bowtie2.sh SE Trimmed/Trimmomatic ../Ref/refdata-Bowtie2-mm39/mm39
```

Perform a quality check after alignment to ensure reads were correctly mapped.  
```bash
sh 1_QC.sh Mapped/mm39/BAM
```

### 4. Filtering and indexing BAM
Syntax : ```sh 4_BowtieCheck.sh [options] <input_dir1> <...>```  
```bash
# Here we set -R false because duplicated reads were removed by Clumpify during Trimming step
sh 4_BowtieCheck.sh -N '_sorted' -T 10 -R false Mapped/mm39/BAM 
```

### 5. Peak Calling
Syntax : ```sh 5_PeakyFinders.sh [options] <chrom_size> <input_dir1> <...>```  
```bash
# Using MACS2
sh 5_PeakyFinders.sh -U 'MACS2' -N '_filtered' Mapped/mm39/BAM ../Ref/Genome/mm39.chrom.sizes

# Using HOMER
sh 5_PeakyFinders.sh -U 'HOMER' -N '_filtered' -S 50 -M dnase -L 4 -C 2 Mapped/mm39/BAM ../Ref/Genome/mm39.chrom.sizes
```
*Note : while using HOMER, define -M option accordingly to the type of data. Use **dnase** for chromatin accessibility, **histone** for epigenetic marks and **factor** for CUT&RUN. More options are available for both HOMER or MACS2, see script documentation.*  

### 6. Peak Annotation
Syntax : ```sh 6_Annotate.sh [options] <input_dir> <FASTA> <GTF>```  
```bash
sh 6_Annotate.sh -R 200 -L '8,10,12' -A true -M true ./HOMER/Peaks ../Ref/Genome/Mus_musculus.GRCm39.dna_sm.primary_assembly.fa ../Ref/Genome/Mus_musculus.GRCm39.108.gtf
```

### 7. Association Motif-Peaks
Syntax : ```sh 7_WinPeaks.sh [options] <input_dir> <FASTA> <GTF> <MOTIF>```  
```bash
sh 7_WinPeaks.sh -F bed ./HOMER/Peaks ../Ref/Genome/Mus_musculus.GRCm39.dna_sm.primary_assembly.fa ../Ref/Genome/Mus_musculus.GRCm39.108.gtf ../Ref/Motifs/FACTOR.motif
```
  
# Workflow in a Nutshell
```bash
# Quality Check
sh 1_QC.sh Raw
# Trimming and duplicate removal
sh 2_Trim.sh -U 'Both' -S 4:15 -L 5 -T 5 -M 36 -I ../Ref/Trimmomatic/TruSeq3-SE_NexteraPE-PE.fa:2:30:10 -D True SE Raw
# Quality Check
sh 1_QC.sh Trimmed/Trimmomatic

# Mapping to genome
sh 3_Bowtie2.sh SE Trimmed/Trimmomatic ../Ref/refdata-Bowtie2-mm39/mm39
sh 1_QC.sh Mapped/mm39/BAM
# Filtering
sh 4_BowtieCheck.sh -T 10 Mapped/mm39/BAM 

# Peak calling using HOMER
sh 5_PeakyFinders.sh -U 'HOMER' -M factor Mapped/mm39/BAM ../Ref/Genome/mm39.chrom.sizes
# Peak calling using MACS2
sh 5_PeakyFinders.sh -U 'MACS2' Mapped/mm39/BAM ../Ref/Genome/mm39.chrom.sizes

# Peak and motifs annotation
sh 6_Annotate.sh HOMER/Peaks ../Ref/Genome/Mus_musculus.GRCm39.dna_sm.primary_assembly.fa ../Ref/Genome/Mus_musculus.GRCm39.108.gtf
sh 7_WinPeaks.sh HOMER/Peaks ../Ref/Genome/Mus_musculus.GRCm39.dna_sm.primary_assembly.fa ../Ref/Genome/Mus_musculus.GRCm39.108.gtf ../Ref/Motifs/FACTOR.motif
```


