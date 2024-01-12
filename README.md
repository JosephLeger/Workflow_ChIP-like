# Epigenetics
Custom pipeline for epigenetic profiling, chromatin accessibility and CUT&amp;RUN analysis



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




