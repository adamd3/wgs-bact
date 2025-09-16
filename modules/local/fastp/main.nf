process FASTP {
    tag "$meta.id"
    label 'process_medium'

    conda "bioconda::fastp=0.23.2"
    container "biocontainers/fastp:0.23.2--h79da9fb_0"

    input:
    tuple val(meta), path(reads)

    output:
    tuple val(meta), path("*.trimmed.fastq.gz"), emit: reads
    path "*.json", emit: json
    path "*.html", emit: html
    path "versions.yml", emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    """
    echo "This is a placeholder script"
    touch placeholder.trimmed.fastq.gz
    touch placeholder.json
    touch placeholder.html
    touch versions.yml
    """
}
