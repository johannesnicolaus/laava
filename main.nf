#!/usr/bin/env nextflow
/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    formbio/laava
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    Github : https://github.com/formbio/laava
    Website: https://formbio.com
----------------------------------------------------------------------------------------
*/

nextflow.enable.dsl = 2

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    VALIDATE & PRINT PARAMETER SUMMARY
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

// Print help message if needed
if (params.help) {
    def logo = """\
        ==============================================
         ██╗      █████╗  █████╗ ██╗   ██╗ █████╗
         ██║     ██╔══██╗██╔══██╗██║   ██║██╔══██╗
         ██║     ███████║███████║██║   ██║███████║
         ██║     ██╔══██║██╔══██║╚██╗ ██╔╝██╔══██║
         ███████╗██║  ██║██║  ██║ ╚████╔╝ ██║  ██║
         ╚══════╝╚═╝  ╚═╝╚═╝  ╚═╝  ╚═══╝  ╚═╝  ╚═╝
        ==============================================
         Long-read AAV Analysis v${workflow.manifest.version}
        ==============================================
        """.stripIndent()
    
    def help_msg = """\
        Usage:
          nextflow run main.nf --seq_reads_file <file> --vector_fa <file> --vector_bed <file> --outdir <dir> -profile <profile>
        
        Required arguments:
          --vector_fa                   Vector reference FASTA file
          --vector_bed                  Vector annotation BED file
          --outdir                      Output directory
        
        Input options (one required):
          --seq_reads_file              Single sequence file (BAM/FASTQ)
          --seq_reads_folder            Folder containing multiple sequence files
        
        Optional arguments:
          --sample_in_metadata          TSV file with sample metadata
          --packaging_fa                Packaging reference FASTA file
          --host_fa                     Host reference FASTA file
          --flipflop_fa                 Flipflop reference FASTA file
          --vector_type                 Vector type (ss/sc) [default: unspecified]
        
        Profiles:
          -profile docker               Use Docker containers
          -profile singularity          Use Singularity containers
          -profile local                Local execution
          -profile <institution>        Use institutional config (e.g., oist, crick, etc.)
        """.stripIndent()
    
    log.info logo + help_msg
    System.exit(0)
}

// Basic parameter validation
if (!params.vector_fa) {
    log.error "ERROR: --vector_fa is required"
    System.exit(1)
}
if (!params.vector_bed) {
    log.error "ERROR: --vector_bed is required" 
    System.exit(1)
}
if (!params.seq_reads_file && !params.seq_reads_folder) {
    log.error "ERROR: Either --seq_reads_file or --seq_reads_folder is required"
    System.exit(1)
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    NAMED WORKFLOW FOR PIPELINE
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

include { LAAVA } from './workflows/laava'

//
// WORKFLOW: Run main laava analysis pipeline
//
workflow FORMBIO_LAAVA {
    LAAVA ()
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    RUN ALL WORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

//
// WORKFLOW: Execute a single named workflow for the pipeline
//
workflow {
    FORMBIO_LAAVA ()
}
