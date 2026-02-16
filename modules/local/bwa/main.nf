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
    tuple val(meta), path(reads), path(indexed_ref_dir), path(indexed_fasta_path)

    output:
    def original_ref_basename = indexed_ref_dir.baseName.replace(".bwa_idx", "") // This definition is now here
    def output_name = "${meta.id}.${original_ref_basename}"                  // This definition is now here
    tuple val(meta), path(
        {
            def original_ref_basename_closure = indexed_ref_dir.baseName.replace(".bwa_idx", "")
            def output_name_closure = "${meta.id}.${original_ref_basename_closure}"
            return "${output_name_closure}.bam"
        }.call()
    ), path(
        {
            def original_ref_basename_closure = indexed_ref_dir.baseName.replace(".bwa_idx", "")
            def output_name_closure = "${meta.id}.${original_ref_basename_closure}"
            return "${output_name_closure}.bam.bai"
        }.call()
    ), emit: bam

    publishDir "${params.outdir}/bwa_alignments", pattern: "*.{bam,bam.bai}", mode: "copy"

    script:
    def name = output_name // Keep 'name' for script context convenience

    if (meta.single_end) {
        """
        # Create a symlink to the indexed reference directory staged by Nextflow
        # This allows bwa mem to find the index files relative to the FASTA
        ln -s ${indexed_ref_dir} ./${original_ref_basename}.bwa_idx_link
        
        # Now run bwa mem using the reference file inside the symlinked directory
        bwa mem -t ${task.cpus} ./${original_ref_basename}.bwa_idx_link/${indexed_fasta_path.name} \\
            ${reads[0]} | \\
            samtools sort -@ ${task.cpus - 1} -O bam - > ${name}.bam
        samtools index -@ ${task.cpus} ${name}.bam
        """
    } else {
        """
        # Create a symlink to the indexed reference directory staged by Nextflow
        # This allows bwa mem to find the index files relative to the FASTA
        ln -s ${indexed_ref_dir} ./${original_ref_basename}.bwa_idx_link
        
        # Now run bwa mem using the reference file inside the symlinked directory
        bwa mem -t ${task.cpus} ./${original_ref_basename}.bwa_idx_link/${indexed_fasta_path.name} \\
            ${reads[0]} ${reads[1]} | \\
            samtools sort -@ ${task.cpus - 1} -O bam - > ${name}.bam
        samtools index -@ ${task.cpus} ${name}.bam
        """
    }
}
