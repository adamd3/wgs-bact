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
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    def is_single_end = meta.single_end

    if (is_single_end) {
        """
        fastp \
            -i $reads \
            -o ${prefix}.trimmed.fastq.gz \
            -j ${prefix}.json \
            -h ${prefix}.html \
            $args

        cat <<-END_VERSIONS > versions.yml
        "${task.process}":
            fastp: \$(fastp --version 2>&1 | sed 's/fastp //')
        END_VERSIONS
        """
    } else {
        """
        fastp \
            -i ${reads[0]} \
            -I ${reads[1]} \
            -o ${prefix}_1.trimmed.fastq.gz \
            -O ${prefix}_2.trimmed.fastq.gz \
            -j ${prefix}.json \
            -h ${prefix}.html \
            $args

        cat <<-END_VERSIONS > versions.yml
        "${task.process}":
            fastp: \$(fastp --version 2>&1 | sed 's/fastp //')
        END_VERSIONS
        """
    }
}
