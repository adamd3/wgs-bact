#!/usr/bin/env nextflow
/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    wgs-bact
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    Github : https://github.com/adamdinan/wgs-bact
    Website: 
    Slack  : 
----------------------------------------------------------------------------------------
*/

nextflow.enable.dsl = 2

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT FUNCTIONS / MODULES / SUBWORKFLOWS / WORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

include { SRA                     } from './workflows/sra'
include { FASTP                   } from './modules/local/fastp/main.nf'
include { SNIPPY                  } from './modules/local/snippy'
include { MERGE_FASTQ             } from './modules/local/merge_fastq/main.nf'
include { PIPELINE_INITIALISATION; PIPELINE_COMPLETION } from './subworkflows/local/utils_wgs_bact_pipeline'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    NAMED WORKFLOWS FOR PIPELINE
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

//
// WORKFLOW: Run main wgs-bact analysis pipeline depending on type of identifier provided
// This is a minor change to trigger CI.
//
workflow WGS_BACT {

    take:
    ids // channel: database ids read in from --input
    reference_genome // path: reference genome file

    main:

    //
    // WORKFLOW: Download FastQ files for SRA / ENA / GEO / DDBJ ids
    //
    SRA ( ids )

    //
    // MODULE: Run fastp to trim reads
    //
    FASTP ( SRA.out.sra_metadata.map { meta ->
        def reads = []
        if (meta.single_end) {
            reads = [ file(meta.fastq_1) ]
        } else {
            reads = [ file(meta.fastq_1), file(meta.fastq_2) ]
        }
        [ meta, reads ]
    } )

    //
    // MODULE: Run Snippy to call variants
    //
    SNIPPY (
        FASTP.out.reads.map { meta, reads -> [ meta, reads, reference_genome, null ] }
    )

    //
    // Group FASTQ files by sample_accession and merge them
    //
    FASTP.out.reads
        .groupTuple(by: [0]) // Group by the first element of the tuple, which is 'meta'
        .map { meta, reads_list ->
            def r1_files = []
            def r2_files = []
            def single_end = false

            reads_list.each { reads ->
                if (reads.size() == 1) {
                    r1_files << reads[0]
                    single_end = true
                } else {
                    r1_files << reads[0]
                    r2_files << reads[1]
                }
            }
            // Ensure meta.single_end is correctly set for the merged sample
            meta.single_end = single_end
            [ meta, [r1_files, r2_files] ]
        }
        .set { grouped_reads_for_merging }

    MERGE_FASTQ (
        grouped_reads_for_merging
    )

    //
    // MODULE: Run Snippy on merged samples
    //
    SNIPPY (
        MERGE_FASTQ.out.merged_reads.map { meta, reads -> [ meta, reads, reference_genome ] },
        "merged_snippy" // Add a suffix to the output directory for merged snippy results
    )

}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    RUN MAIN WORKFLOW
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow {

    //
    // SUBWORKFLOW: Run initialisation tasks
    //
    PIPELINE_INITIALISATION (
        params.version,
        params.help,
        params.validate_params,
        params.monochrome_logs,
        args,
        params.outdir,
        params.input,
        params.ena_metadata_fields
    )

    //
    // WORKFLOW: Run primary workflows for the pipeline
    //
    WGS_BACT (
        PIPELINE_INITIALISATION.out.ids,
        file(params.reference_genome)
    )

    //
    // SUBWORKFLOW: Run completion tasks
    //
    PIPELINE_COMPLETION (
        params.email,
        params.email_on_fail,
        params.plaintext_email,
        params.outdir,
        params.monochrome_logs,
        params.hook_url
    )
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    THE END
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/