# Gemini Added Functionality

This section describes the functionality added by the Gemini CLI agent.

## FASTQ Merging and Second Snippy Run for Multi-Run BioSamples

The Nextflow pipeline has been enhanced to handle BioSamples that have multiple sequencing runs. Previously, the pipeline would process each run individually, leading to multiple variant calling results for a single BioSample.

The new functionality introduces the following steps:

1.  **Individual Run Processing:** The pipeline continues to perform `fastp` trimming and `SNIPPY` variant calling on each individual sequencing run.
2.  **FASTQ Merging:** After the initial `fastp` processing, FASTQ files belonging to the same `sample_accession` (BioSample) are grouped together. For each BioSample with multiple runs, the corresponding R1 (and R2 for paired-end) FASTQ files are concatenated into a single merged R1 (and R2) FASTQ file.
3.  **Merged Sample Variant Calling:** A second `SNIPPY` process is then executed on these newly generated merged FASTQ files. This ensures that a single variant call set is produced for each unique BioSample, regardless of how many runs contributed to it.

The output from the `SNIPPY` process on merged samples is directed to a separate output directory (suffixed with `_merged_snippy`) to distinguish it from the individual run results.