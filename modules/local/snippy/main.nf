process SNIPPY {
    tag "${meta.id}"
    label 'process_high' // Snippy can be resource intensive

    conda (params.enable_conda ? "bioconda::snippy=4.6.0" : null)
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/snippy:4.6.0--hdfd78af_1' :
        'quay.io/biocontainers/snippy:4.6.0--hdfd78af_1' }"

    input:
    tuple val(meta), path(reads), path(reference)

    output:
    tuple val(meta), path("${meta.id}_snippy") , emit: snippy_results
    path "versions.yml"                       , emit: versions

    script:
    def args = task.ext.args ?: params.snippy_args
    def prefix = task.ext.prefix ?: meta.id
    def input_reads = reads.join(' --R1 ').replaceFirst(' --R1 ', '') // Handle single-end and paired-end

    """
mkdir ${prefix}_snippy

    if [ "${reads.size()}" == "1" ]; then
        snippy \
            --outdir ${prefix}_snippy \
            --ref ${reference} \
            --se ${reads[0]} \
            --cpus ${task.cpus} \
            --mapqual ${params.snippy_min_mapqual} \
            --basequal ${params.snippy_min_basequal} \
            --mincov ${params.snippy_min_coverage} \
            --minfrac ${params.snippy_min_frac} \
            --minqual ${params.snippy_min_qual} \
            --maxsoft ${params.snippy_max_soft} \
            ${args}
    else
        snippy \
            --outdir ${prefix}_snippy \
            --ref ${reference} \
            --R1 ${reads[0]} \
            --R2 ${reads[1]} \
            --cpus ${task.cpus} \
            --mapqual ${params.snippy_min_mapqual} \
            --basequal ${params.snippy_min_basequal} \
            --mincov ${params.snippy_min_coverage} \
            --minfrac ${params.snippy_min_frac} \
            --minqual ${params.snippy_min_qual} \
            --maxsoft ${params.snippy_max_soft} \
            ${args}
    fi

    cat <<-END_VERSIONS > versions.yml
    "SNIPPY":
        snippy: 
    END_VERSIONS
    """
}