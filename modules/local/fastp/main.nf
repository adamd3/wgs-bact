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

    """
    echo "--- FASTP Debug Info ---"
    echo "Input reads: ${reads}"
    echo "Is single-end: ${is_single_end}"
    echo "Prefix: ${prefix}"

    if [ "${is_single_end}" == "true" ]; then
        echo "Running fastp for single-end reads..."
        fastp \
            -i ${reads} \
            -o ${prefix}.trimmed.fastq.gz \
            -j ${prefix}.json \
            -h ${prefix}.html \
            ${args}
        
        if [ ! -f "${prefix}.trimmed.fastq.gz" ]; then
            echo "Error: Expected single-end trimmed FastQ file not found!"
            exit 1
        fi
        echo "Output file: ${prefix}.trimmed.fastq.gz"
        ls -l ${prefix}.trimmed.fastq.gz
    else
        echo "Running fastp for paired-end reads..."
        fastp \
            -i ${reads[0]} \
            -I ${reads[1]} \
            -o ${prefix}_1.trimmed.fastq.gz \
            -O ${prefix}_2.trimmed.fastq.gz \
            -j ${prefix}.json \
            -h ${prefix}.html \
            ${args}

        if [ ! -f "${prefix}_1.trimmed.fastq.gz" ] || [ ! -f "${prefix}_2.trimmed.fastq.gz" ]; then
            echo "Error: Expected paired-end trimmed FastQ files not found!"
            exit 1
        fi
        echo "Output files: ${prefix}_1.trimmed.fastq.gz ${prefix}_2.trimmed.fastq.gz"
        ls -l ${prefix}_1.trimmed.fastq.gz ${prefix}_2.trimmed.fastq.gz
    fi

    echo "--- End FASTP Debug Info ---"

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        fastp: 
    END_VERSIONS
    """
}