process MERGE_FASTQ {
    tag "${meta.sample_accession}"
    label "process_medium"

    conda (params.enable_conda ? "bioconda::fastp=0.23.2" : null)
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ? \
        'https://depot.galaxyproject.org/singularity/fastp:0.23.2--h78949ad_0' : \
        'quay.io/biocontainers/fastp:0.23.2--h78949ad_0' }"

    input:
    tuple val(meta), path(reads)

    output:
    tuple val(meta), path("*.fastq.gz"), emit: merged_reads
    path "versions.yml"             , emit: versions

    script:
    def prefix = meta.sample_accession
    if (meta.single_end) {
        """
        cat \$(echo ${reads.join(' ')} | tr ' ' '\\n' | sort -V | tr '\\n' ' ') > ${prefix}.fastq.gz
        cat <<-END_VERSIONS > versions.yml
        "${task.process}":
            fastp: $$(fastp --version 2>&1 | sed '1!d' | sed 's/^fastp //g')
        END_VERSIONS
        """
    } else {
        """
        cat \$(echo ${reads[0].join(' ')} | tr ' ' '\\n' | sort -V | tr '\\n' ' ') > ${prefix}_1.fastq.gz
        cat \$(echo ${reads[1].join(' ')} | tr ' ' '\\n' | sort -V | tr '\\n' ' ') > ${prefix}_2.fastq.gz
        cat <<-END_VERSIONS > versions.yml
        "${task.process}":
            fastp: $$(fastp --version 2>&1 | sed '1!d' | sed 's/^fastp //g')
        END_VERSIONS
        """
    }
}
