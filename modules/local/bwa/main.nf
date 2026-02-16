// modules/local/bwa/main.nf
nextflow.enable.dsl = 2

process BWA_INDEX {
    tag "bwa_index_${reference.baseName}"
    label 'process_high'
    conda (params.enable_conda ? "${baseDir}/modules/local/bwa/environment.yml" : null)

    input:
    path reference

    output:
    path "${reference.baseName}.bwa_idx" , emit: index
    path "${reference.baseName}.bwa_idx/${reference.name}" , emit: indexed_reference

    script:
    """
    mkdir ${reference.baseName}.bwa_idx
    cp ${reference} ${reference.baseName}.bwa_idx/${reference.name}
    bwa index ${reference.baseName}.bwa_idx/${reference.name}
    """
}

process BWA_MEM {
    tag "$meta.id"
    label 'process_high'
    conda (params.enable_conda ? "${baseDir}/modules/local/bwa/environment.yml" : null)

    input:
    tuple val(meta), path(reads), path(indexed_ref_dir) // Changed input

    output:
    tuple val(meta), path("${name}.bam"), path("${name}.bam.bai"), emit: bam

    publishDir "${params.outdir}/bwa_alignments", pattern: "*.{bam,bam.bai}", mode: "copy"

    script:
    def original_ref_basename = indexed_ref_dir.baseName.replace(".bwa_idx", "") // e.g., GCF_000016305.1_ASM1630v1_genomic
    def ref_fasta_in_dir = indexed_ref_dir.list().find{ it.name.endsWith(".fna") || it.name.endsWith(".fasta") || it.name.endsWith(".fa") } // Find the actual fasta file in the directory
    def name = "${meta.id}.${original_ref_basename}"

    if (meta.single_end) {
        """
        # Create a symlink to the indexed reference directory
        ln -s ${indexed_ref_dir} ./${original_ref_basename}.bwa_idx_link

        # Now run bwa mem using the reference file inside the symlinked directory
        bwa mem -t ${task.cpus} ./${original_ref_basename}.bwa_idx_link/${ref_fasta_in_dir.name} \\
            ${reads[0]} | \\
            samtools sort -@ ${task.cpus - 1} -O bam - > ${name}.bam
        samtools index -@ ${task.cpus} ${name}.bam
        """
    } else {
        """
        # Create a symlink to the indexed reference directory
        ln -s ${indexed_ref_dir} ./${original_ref_basename}.bwa_idx_link

        # Now run bwa mem using the reference file inside the symlinked directory
        bwa mem -t ${task.cpus} ./${original_ref_basename}.bwa_idx_link/${ref_fasta_in_dir.name} \\
            ${reads[0]} ${reads[1]} | \\
            samtools sort -@ ${task.cpus - 1} -O bam - > ${name}.bam
        samtools index -@ ${task.cpus} ${name}.bam
        """
    }
}
