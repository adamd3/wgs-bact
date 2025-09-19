
process SNIPPY {
    tag "${meta.id}"
    label 'process_high' // Snippy can be resource intensive

    conda (params.enable_conda ? "bioconda::snippy=4.6.0" : null)
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/snippy:4.6.0--hdfd78af_1' :
        'quay.io/biocontainers/snippy:4.6.0--hdfd78af_1' }"

    input:
    tuple val(meta), path(reads_list), path(reference)

    output:
    tuple val(meta), path("${meta.id}_snippy") , emit: snippy_results
    path "versions.yml"                       , emit: versions

    script:
    def args = task.ext.args ?: params.snippy_args
    def prefix = task.ext.prefix ?: meta.id

    """
    echo "--- SNIPPY Debug Info ---"
    echo "Input reads: ${reads_list}"
    echo "Reference: ${reference}"
    echo "Prefix: ${prefix}"

    mkdir ${prefix}_snippy

    if ${meta.single_end}; then
        echo "Running snippy for single-end reads..."
        snippy \
            --outdir ${prefix}_snippy \
            --force \
            --ref ${reference} \
            --se "${reads_list[0]}" \
            --cpus ${task.cpus} \
            --mapqual ${params.snippy_min_mapqual} \
            --basequal ${params.snippy_min_basequal} \
            --mincov ${params.snippy_min_coverage} \
            --minfrac ${params.snippy_min_frac} \
            --minqual ${params.snippy_min_qual} \
            --maxsoft ${params.snippy_max_soft} \
            ${args} 2>&1 | tee snippy_output.log
        if [ \$? -ne 0 ]; then
            echo "Error: Snippy command failed. See snippy_output.log for details."
            cat snippy_output.log
            exit 1
        fi
    else
        echo "Running snippy for paired-end reads..."
        snippy \
            --outdir ${prefix}_snippy \
            --force \
            --ref ${reference} \
            --R1 "${reads_list[0]}" \
            --R2 "${reads_list[1]}" \
            --cpus ${task.cpus} \
            --mapqual ${params.snippy_min_mapqual} \
            --basequal ${params.snippy_min_basequal} \
            --mincov ${params.snippy_min_coverage} \
            --minfrac ${params.snippy_min_frac} \
            --minqual ${params.snippy_min_qual} \
            --maxsoft ${params.snippy_max_soft} \
            ${args} 2>&1 | tee snippy_output.log
        if [ \$? -ne 0 ]; then
            echo "Error: Snippy command failed. See snippy_output.log for details."
            cat snippy_output.log
            exit 1
        fi
    fi

    cat <<-END_VERSIONS > versions.yml
    "SNIPPY":
        snippy:
    END_VERSIONS
    """