process CLEANUP_FASTQ_DIRS {
    tag "Cleanup intermediate FASTQ directories"
    label 'process_low'

    input:
    val(done_signal) // Dummy input to ensure it runs after WGS_BACT
    val(outdir)
    val(save_intermediate_fastqs)

    script:
    if (!save_intermediate_fastqs) {
        """
        echo "Cleaning up intermediate FASTQ directories..."
        rm -rf ${outdir}/fastq
        rm -rf ${outdir}/fastp
        echo "Cleanup complete."
        """
    } else {
        """
        echo "Intermediate FASTQ directories are being saved as per user request."
        """
    }
}
