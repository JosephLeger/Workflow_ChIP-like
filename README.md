# Workflow description

This workflow was designed to perform analyzes of chromatin accessibility or ChIP-like data, from FASTQ files to peak calling and motif enrichment analysis.  
It is deliberately not automated, and requires launching the scripts manually one after the other, keeping full user control and allowing custom options, whilst retaining some standardization and repeatability. Therefore, it is well suited to projects with a not too high number of experiments, and for users who want to perform analyzes step by step by taking the time to understand the results of one step before launching the next, and possibly change the options accordingly.

<img src="https://github.com/JosephLeger/Epigenetics/blob/main/img/pipeline.png"  width="60%" height="60%">

### Summary of Steps

1. **Quality Check :** Quality of each FASTQ file is performed using **FastQC**. A quality control report per file is then obtained, providing information on the quality of the bases, the length of the reads, the presence of adapters, etc. To make it easier to visualize the results, all reports are then pooled and analyzed simultaneously using **MultiQC**.

2. **Trimming :** According to the conclusions drawn from the quality control of the reads, a trimming step is often necessary. This step makes it possible to clean the reads, for example by eliminating sequences enriched in adapters, or by trimming poor quality bases at the ends of the reads. For this, the **Trimmomatic** tool needs to be provided with the adapter sequences used for sequencing if an enrichment has been detected.  
A quality control is carried out on the FASTQ files resulting from trimming to ensure that the quality obtained is satisfactory.
Trimming script includes the optional use of **Clumpify** (bbmap) to remove duplicated reads at FASTQ stage and to optimize file organization.  

4. **Alignment to the Genome :** This step consists of aligning the FASTQ files to a previously indexed reference genome in order to identify the regions from which the reads come. This workflow uses **Bowtie2**, a widely used tool for read mapping, to generate sorted BAM files.  
*Note : it requires a genome reference indexing step, or to download already indexed genome.*  

5. **Filtering and Indexing BAM :** If it hasn't already been done duplicated reads are removed, and reads with low alignment scores are filtered out using **Picard** and **SamTools**. Resulting BAM files are then indexed for following steps.  

6. **Peak Calling :** To identify notable regions, aligned reads are then convert to peaks regions. This workflow provides two different widely used peak caller, **MACS2** and **HOMER**. Both will generate specific peak files, that are then converted into BED, BEDGRAPH and BIGWIG formats.  


# Indexing the reference Genome

# Requirements
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

# Workflow Step by Step

Syntax : ```sh 1_QC.sh <input_dir>```  
```bash
sh 1_QC.sh Raw
```

Syntax : ```sh 2_MultiQC.sh <input_dir>```  
```bash
sh 2_MultiQC.sh QC/Raw
```

Syntax : ```sh 3_Trim.sh [options] <SE|PE> <input_dir>```  
```bash
sh 3_Trim.sh -U 'Both' -S 4:15 -L 5 -T 5 -M 36 -I ./Ref/TruSeq3-SE_NexteraPE-PE.fa:2:30:7 SE Raw
```

Syntax : ```sh 4_Bowtie2.sh [options] <SE|PE> <input_dir> <refindex>```   
```bash
sh 4_Bowtie2.sh SE Trimmed/Trimmomatic ./Ref/refdata-Bowtie2-mm39/mm39
```

Syntax : ```sh 5_BowtieCheck.sh [options] <input_dir1> <...>```  
```bash
# -R false because duplicated were remove by Clumpify
sh 5_BowtieCheck.sh -N '_sorted' -T 10 -R false Mapped/mm39/BAM 
```

Syntax : ```sh 6_PeakyFinders.sh [options] <chrom_size> <input_dir1> <...>```  
```bash
# Using MACS2
sh 7_PeakyFinders.sh -U 'MACS2' -N '_filtered' Mapped/mm39/BAM

# using HOMER
sh 7_PeakyFinders -U 'HOMER'-N '_filtered' -S 50 -M dnase -L 4 -C 2 ./Ref/mm39.chrom.sizes Mapped/mm39/BAM
```
*Note : adapt -M option according to the type of data. Use **dna** for chromatin accessibility, **histone** for epigenetic marks and **factor** for CUT&RUN.*  


Syntax : ```sh 7_Annotate.sh [options] <input_dir> <FASTA> <GTF>```  
```bash
sh 8_Annotate.sh -R 200 -L '8,10,12' -A true -M true ./Peaks ./Ref/Mus_musculus.GRCm39.dna_sm.primary_assembly.fa ./Ref/Mus_musculus.GRCm39.108.gtf
```

Syntax : ```sh 8_WinPeaks.sh [options] <input_dir> <FASTA> <GTF> <MOTIF>```  
```bash
sh 9_WinPeaks.sh -F bed./Peaks ./Ref/Genome/Mus_musculus.GRCm39.dna_sm.primary_assembly.fa ./Ref/Mus_musculus.GRCm39.108.gtf ./Motifs/FACTOR.motif
```




