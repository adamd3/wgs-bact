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
include { PIPELINE_INITIALISATION } from './subworkflows/local/utils_wgs_bact_pipeline'
include { PIPELINE_COMPLETION     } from './subworkflows/local/utils_wgs_bact_pipeline'

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

    // Collect FASTP outputs into a single channel for SNIPPY
    ch_fastp_reads = Channel.empty()

    FASTP.out.reads
        .map { meta, read_file -> [ meta, [read_file] ] }
        .set { ch_single_end_output }

    FASTP.out.reads_paired
        .map { meta, read1, read2 -> [ meta, [read1, read2] ] }
        .set { ch_paired_end_output }

    ch_fastp_reads = ch_single_end_output.mix(ch_paired_end_output)

    //
    // MODULE: Run Snippy to call variants
    //
    SNIPPY (
        ch_fastp_reads.map { meta, reads -> [ meta, reads, reference_genome ] }
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