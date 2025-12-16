process MERGE_FASTQ {
    tag "${meta.sample_accession}"
    label "process_medium"

    conda (params.enable_conda ? "bioconda::fastp=0.23.2" : null)
    container 'quay.io/biocontainers/fastp:0.23.2'

    input:
    tuple val(meta), path(r1_files), path(r2_files)

    output:
    tuple val(meta), path("*.fastq.gz"), emit: merged_reads
    path "versions.yml"             , emit: versions

    publishDir "${params.outdir}/fastq_merged", pattern: "*.fastq.gz", mode: "copy", enabled: params.save_intermediate_fastqs

    script:
    def prefix = meta.sample_accession.replaceAll(';', '_')
    def r1_filtered = r1_files.findAll { it.exists() && it.isFile() }
    def r2_filtered = r2_files.findAll { it.exists() && it.isFile() }

    if (meta.single_end) {
        """
        cat \$(echo ${r1_filtered.join(' ')} | tr ' ' '\\n' | sort -V | tr '\\n' ' ') > ${prefix}.fastq.gz
        cat <<-END_VERSIONS > versions.yml
        "${task.process}":
            fastp: \$(fastp --version 2>&1 | sed '1!d' | sed 's/^fastp //g')
        END_VERSIONS
        """
    } else {
        """
        cat \$(echo ${r1_filtered.join(' ')} | tr ' ' '\\n' | sort -V | tr '\\n' ' ') > ${prefix}_1.fastq.gz
        cat \$(echo ${r2_filtered.join(' ')} | tr ' ' '\\n' | sort -V | tr '\\n' ' ') > ${prefix}_2.fastq.gz
        cat <<-END_VERSIONS > versions.yml
        "${task.process}":
            fastp: \$(fastp --version 2>&1 | sed '1!d' | sed 's/^fastp //g')
        END_VERSIONS
        """
    }
}
