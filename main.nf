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
include { SNIPPY; SNIPPY as SNIPPY_MERGED } from './modules/local/snippy'
include { MERGE_FASTQ             } from './modules/local/merge_fastq/main.nf'
include { CLEANUP_FASTQ_DIRS      } from './modules/local/cleanup_fastq_dirs/main.nf'
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
    FASTP ( SRA.out.sra_metadata.map { original_meta ->
        def reads = []
        if (original_meta.single_end) {
            reads = [ file(original_meta.fastq_1) ]
        } else {
            reads = [ file(original_meta.fastq_1), file(original_meta.fastq_2) ]
        }
        // Create a new meta object to ensure 'id' is explicitly set
        def new_meta = original_meta.clone()
        new_meta.id = original_meta.run_accession // Use run_accession as the primary ID for individual runs
        [ new_meta, reads ]
    } )

    //
    // MODULE: Run Snippy to call variants
    //
    SNIPPY (
        FASTP.out.reads.map { original_meta, reads -> [ original_meta, reads, reference_genome, null, original_meta.run_accession ] }
    )

    //
    // Group FASTQ files by sample_accession and merge them
    //
    FASTP.out.reads
        .map { meta, reads -> [ meta.sample_accession, meta, reads ] } // Add sample_accession as the first element for explicit grouping
        .groupTuple(by: [0]) // Group by sample_accession
        .map { sample_accession, meta_list, reads_list ->
            def r1_files = []
            def r2_files = []
            def single_end = false
            def merged_meta = meta_list[0] // Take the first meta object as the representative for the merged sample

            reads_list.each { reads ->
                if (reads.size() == 1) {
                    r1_files << reads[0]
                    single_end = true
                } else {
                    r1_files << reads[0]
                    r2_files << reads[1]
                }
            }
            // Ensure merged_meta.single_end is correctly set for the merged sample
            merged_meta.single_end = single_end
            merged_meta.id = merged_meta.sample_accession // Set the ID for the merged sample
            // Add a flag to indicate if this sample_accession has multiple runs
            [ merged_meta, r1_files, r2_files, meta_list.size() > 1 ]
        }
        .filter { meta, r1_files, r2_files, is_multi_run -> is_multi_run && !meta.sample_accession.contains(';') } // Only pass multi-run samples and filter out multi-sample accessions
        .map { meta, r1_files, r2_files, is_multi_run -> // Remove the is_multi_run flag before passing to MERGE_FASTQ
            if (meta.single_end) {
                [ meta, r1_files ]
            } else {
                [ meta, r1_files, r2_files ]
            }
        }
        .set { grouped_reads_for_merging }

    MERGE_FASTQ (
        grouped_reads_for_merging
    )

    //
    // MODULE: Run Snippy on merged samples
    //
    SNIPPY_MERGED (
        MERGE_FASTQ.out.merged_reads.map { meta, reads -> [ meta, reads, reference_genome, "merged", meta.id ] }
    )

    // Emit a signal when the workflow is done
    // This channel will only emit once all upstream processes have completed
    Channel
        .empty()
        .mix(SNIPPY.out.snippy_results.last()) // Ensure SNIPPY is done
        .mix(SNIPPY_MERGED.out.snippy_results.last()) // Ensure SNIPPY_MERGED is done
        .collect() // Collects all items into a list, then emits the list once
        .map { true } // Emit a single 'true' value
        .set { done_signal }

    emit:
    done = done_signal
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
    CLEANUP_FASTQ_DIRS (
        WGS_BACT.out.done,
        params.outdir,
        params.save_intermediate_fastqs
    )

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