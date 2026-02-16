# Gemini Added Functionality

This section describes the functionality added by the Gemini CLI agent.

## FASTQ Merging and Second Snippy Run for Multi-Run BioSamples

The Nextflow pipeline has been enhanced to handle BioSamples that have multiple sequencing runs. Previously, the pipeline would process each run individually, leading to multiple variant calling results for a single BioSample.

The new functionality introduces the following steps:

1.  **Individual Run Processing:** The pipeline continues to perform `fastp` trimming and `SNIPPY` variant calling on each individual sequencing run.
2.  **FASTQ Merging:** After the initial `fastp` processing, FASTQ files belonging to the same `sample_accession` (BioSample) are grouped together. For each BioSample with multiple runs, the corresponding R1 (and R2 for paired-end) FASTQ files are concatenated into a single merged R1 (and R2) FASTQ file.
3.  **Merged Sample Variant Calling:** A second `SNIPPY` process is then executed on these newly generated merged FASTQ files. This ensures that a single variant call set is produced for each unique BioSample, regardless of how many runs contributed to it.

The output from the `SNIPPY` process on merged samples is directed to a separate output directory (suffixed with `_merged_snippy`) to distinguish it from the individual run results.

## Conditional Variant Calling (Snippy) or Read Alignment (BWA)

The Nextflow pipeline has been further enhanced to provide users with more control over post-trimming analysis steps. After `fastp` trimming, users can now choose between performing variant calling with `SNIPPY`, read alignment with `BWA`, or both.

The new functionality introduces the following:

1.  **New Parameters:**
    *   `--call_vars` (boolean, default `true`): Controls whether `SNIPPY` variant calling is performed.
    *   `--align_reads` (boolean, default `false`): Controls whether `BWA` read alignment is performed.
2.  **Conditional Execution:**
    *   If `--call_vars` is `true`, `SNIPPY` is executed on individual trimmed FASTQ files. If `--merge` is also `true`, `SNIPPY` is run on merged samples as well.
    *   If `--align_reads` is `true`, `BWA_INDEX` is run on the provided reference genome, followed by `BWA_MEM` to align trimmed FASTQ files against the indexed reference.
3.  **BWA Module:** A new local Nextflow module for `BWA` has been created, including:
    *   `BWA_INDEX` process: Indexes the reference genome. Includes a validation step to ensure the reference is in FASTA format.
    *   `BWA_MEM` process: Aligns trimmed reads to the indexed reference, producing sorted and indexed BAM files (`.bam`, `.bam.bai`). This process uses multithreading and publishes outputs to `params.outdir/bwa_alignments`.
    *   A `conda` environment file (`modules/local/bwa/environment.yml`) containing `bwa` and `samtools` dependencies.
4.  **Robustness and Scoping:** Several iterations of bug fixes have been applied to ensure correct variable scoping and channel handling within Nextflow's DSL, particularly for dynamic output naming and tool execution. These fixes address issues like `No such variable`, `Missing output file(s) null.bam`, and `bwa_idx_load_from_disk` errors, ensuring reliable execution.
5.  **Backward Compatibility:** The pipeline remains backward compatible. If the new parameters are not specified, it defaults to running `SNIPPY` (existing behavior) and does not perform `BWA` alignment.
