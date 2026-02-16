// modules/local/bwa/main.nf
nextflow.enable.dsl = 2

process BWA_INDEX {
    tag "bwa_index_${reference.baseName}"
    label 'process_high'

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

    input:
    tuple val(meta), path(reads), path(reference)
    
    output:
    tuple val(meta), path("${name}.bam"), path("${name}.bam.bai"), emit: bam

    publishDir "${params.outdir}/bwa_alignments", pattern: "*.{bam,bam.bai}", mode: "copy"

    script:
    def name = "${meta.id}.${reference.baseName}"
    if (meta.single_end) {
        """
        bwa mem -t ${task.cpus} ${reference} \\
            ${reads[0]} | \\
            samtools sort -@ ${task.cpus - 1} -O bam - > ${name}.bam
        samtools index -@ ${task.cpus} ${name}.bam
        """
    } else {
        """
        bwa mem -t ${task.cpus} ${reference} \\
            ${reads[0]} ${reads[1]} | \\
            samtools sort -@ ${task.cpus - 1} -O bam - > ${name}.bam
        samtools index -@ ${task.cpus} ${name}.bam
        """
    }
}
