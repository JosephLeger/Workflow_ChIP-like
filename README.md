# Epigenetics
Custom pipeline for epigenetic profiling, chromatin accessibility and CUT&amp;RUN analysis




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

```

Syntax : ```sh 5_BowtieCheck.sh [options] <input_dir1> <...>```  
```bash

```

Syntax : ```sh 6_BowtieCheck.sh [options] <chrom_size> <input_dir1> <...>```  
```bash

```

Syntax : ```sh 7_Annotate.sh [options] <input_dir> <FASTA> <GTF>```  
```bash

```

Syntax : ```sh 8_WinPeaks.sh [options] <input_dir> <FASTA> <GTF> <MOTIF>```  
```bash

```




