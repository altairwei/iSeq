#!/bin/bash

# If running for the first time, first grant permission to run the script by running:
# chmod 755 run.sh
# first gunzip all files using the command: find (PATH_OF_THE_FOLDER) -name \*.gz -exec gunzip {} \; 

# for customised python script, add "#!/usr/bin/env python" on the first line, remove .py filename 
# and activate using chmod 755

# $1 = 1st paired-end fastq
# $2 = 2nd paired-end fastq 
# $3 = ref_seq in fasta

set -e -o pipefail
shopt -s failglob
export LC_ALL=C

source activate iSeq

# Declare inputs
PE1=$1
PE2=$2
REF_SEQ=$3
THREADS=6

mkdir -p output

OUTPUT=$(basename $PE1)
OUTPUT=output/${OUTPUT%%.*}

# Build index files for Bowtie2 alignment
bowtie2-build -f $REF_SEQ $REF_SEQ

# Alignment
# --minis set min distance between paired end, default is 0; --maxins set the maximun default is 500 (total length inc read)
# -x = ref fasta; -1 = paired-end read 1; -2 = paired-end read 2; --al-conc = output only concordantly aligned reads
# 2>$3 output the stat of the read
(bowtie2 -p $THREADS --local --minins 0 --maxins 2000 -x $REF_SEQ -1 $PE1 -2 $PE2 -S $OUTPUT.sam --al-conc $OUTPUT.con.sam) 2>$OUTPUT.stat.txt 

# Convert sam to bam file
samtools view -bS $OUTPUT.sam > $OUTPUT.bam

# Sorted bam file
samtools sort $OUTPUT.bam -o ${OUTPUT}_sorted.bam

# Index _sorted.bam file
samtools index ${OUTPUT}_sorted.bam

# Call variant
# samtools mpileup -ugf $3 $3_sorted.bam |bcftools call -vmO v -o $3_call.vcf

# Export pileup as wig using igvtools
igvtools count -z 1 -w 1 --bases ${OUTPUT}_sorted.bam ${OUTPUT}_sorted.wig $REF_SEQ

# Convert wig to csv
mv ${OUTPUT}_sorted.wig ${OUTPUT}_sorted.wig.csv

# Customised python script to call variant (deletion included) based on the most read base
# First argue = csv file from igvtools; second argue = ref fast
./call.py ${OUTPUT}_sorted.wig.csv $REF_SEQ

# Generate consensus txt file
./consensus.py ${OUTPUT}_sorted.wig.csv
