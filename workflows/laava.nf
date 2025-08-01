/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT MODULES / SUBWORKFLOWS / FUNCTIONS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

include { MATCH_METADATA_TO_FILES } from '../modules/local/match_metadata_to_files/main'
include { MAP_READS              } from '../modules/local/map_reads/main'
include { MAKE_REPORT            } from '../modules/local/make_report/main'

// include { INPUT_CHECK            } from '../subworkflows/local/input_check'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT NF-CORE MODULES/SUBWORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

//
// MODULE: Installed directly from nf-core/modules
//
// include { FASTQC                 } from '../modules/nf-core/fastqc/main'
// include { MULTIQC                } from '../modules/nf-core/multiqc/main'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    FUNCTIONS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

// Unpack the input sample(s) and metadata
def prepare_input(
        seq_reads_file, seq_reads_folder, sample_unique_id, sample_display_name,
        sample_in_metadata
) {
    def SAMPLE_FILE_GLOB = "*.{bam,fastq,fastq.gz,fq,fq.gz}"
    def EXTENSION_REGEX = /\.(bam|fastq|fastq\.gz|fq|fq\.gz)$/

    if (seq_reads_folder) {
        // Multi-sample mode
        if (sample_in_metadata) {
            // TSV provided - will be handled by MATCH_METADATA_TO_FILES process
            return "metadata_mode"
        } else {
            // No TSV provided - generate sample_id and sample_name from filenames
            def found_files = file("${seq_reads_folder}/${SAMPLE_FILE_GLOB}")
            return channel.fromList(found_files.collect { seqfile ->
                def stem = seqfile.baseName.replaceFirst(EXTENSION_REGEX, '')
                def sample_meta = [id: stem, single_end: false]
                [sample_meta, seqfile]
            })
        }
    } else if (seq_reads_file) {
        // Single-sample mode
        def seq_file = file(seq_reads_file)
        if (!seq_file.exists()) {
            error "Error: The provided sample file '${seq_reads_file}' does not exist."
        }
        if (!seq_file.name.matches(/.*${EXTENSION_REGEX}/)) {
            error "Error: The provided sample file '${seq_file.name}' does not have a supported extension (bam, fastq, fastq.gz, fq, fq.gz)"
        }

        def stem = seq_file.baseName.replaceFirst(EXTENSION_REGEX, '')
        def sample_id = sample_unique_id ?: stem
        def sample_name = sample_display_name ?: sample_unique_id ?: stem
        def sample_meta = [id: sample_id, single_end: false]
        return channel.of([sample_meta, seq_file])
    } else {
        error "Invalid input parameters. Provide either a sample folder, a TSV file with sample folder, or a single sample file."
    }
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    RUN MAIN WORKFLOW
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow LAAVA {

    take:
    // No input needed - we'll use params directly

    main:

    ch_versions = Channel.empty()
    ch_reports  = Channel.empty()

    // Handle input preparation
    if (params.seq_reads_folder && params.sample_in_metadata) {
        // Use metadata matching process
        def metadata_meta = [id: 'metadata', single_end: false]
        MATCH_METADATA_TO_FILES (
            [metadata_meta, file(params.sample_in_metadata)],
            file(params.seq_reads_folder)
        )
        ch_samples = MATCH_METADATA_TO_FILES.out.metadata
            .splitCsv(sep: '\t')
            .map { row -> 
                def sample_meta = [id: row[0], single_end: false]
                [sample_meta, file("${params.seq_reads_folder}/" + row[2])]
            }
        ch_versions = ch_versions.mix(MATCH_METADATA_TO_FILES.out.versions.first())
    } else {
        // Use direct file input
        ch_samples = prepare_input(
            params.seq_reads_file, 
            params.seq_reads_folder, 
            params.sample_unique_id, 
            params.sample_display_name,
            params.sample_in_metadata
        )
    }

    //
    // MODULE: Map reads to reference
    //
    ch_vector_fa   = params.vector_fa   ? Channel.fromPath(params.vector_fa).collect()   : Channel.empty()
    ch_packaging_fa = params.packaging_fa ? Channel.fromPath(params.packaging_fa).collect() : Channel.value(file("${params.laava_dir}/bin/NO_FILE"))
    ch_host_fa     = params.host_fa     ? Channel.fromPath(params.host_fa).collect()     : Channel.value(file("${params.laava_dir}/bin/NO_FILE2"))

    MAP_READS (
        ch_samples,
        ch_vector_fa,
        ch_packaging_fa,
        ch_host_fa,
        params.repcap_name,
        params.helper_name,
        params.lambda_name
    )
    ch_versions = ch_versions.mix(MAP_READS.out.versions.first())

    //
    // MODULE: Generate report
    //
    ch_vector_bed = params.vector_bed ? Channel.fromPath(params.vector_bed).collect() : Channel.empty()
    ch_flipflop_fa = params.flipflop_fa ? Channel.fromPath(params.flipflop_fa).collect() : Channel.value(file("${params.laava_dir}/bin/NO_FILE"))
    
    MAKE_REPORT (
        MAP_READS.out.mapped_name_bam,
        ch_vector_bed,
        params.itr_label_1,
        params.itr_label_2,
        params.mitr_label,
        params.vector_type,
        params.target_gap_threshold,
        params.max_allowed_outside_vector,
        params.max_allowed_missing_flanking,
        params.min_supp_joint_coverage,
        params.flipflop_name,
        ch_flipflop_fa
    )
    ch_versions = ch_versions.mix(MAKE_REPORT.out.versions.first())

    emit:
    mapped_name_bam   = MAP_READS.out.mapped_name_bam    // channel: [ val(meta), path(tsv), path(bam) ]
    mapped_pos_bam    = MAP_READS.out.mapped_pos_bam     // channel: [ val(meta), path(bam), path(bai) ]
    metadata_tsv      = MAKE_REPORT.out.metadata_tsv     // channel: [ val(meta), path(tsv) ]
    alignments_tsv    = MAKE_REPORT.out.alignments_tsv   // channel: [ val(meta), path(tsv) ]
    per_read_tsv      = MAKE_REPORT.out.per_read_tsv     // channel: [ val(meta), path(tsv) ]
    nonmatch_tsv      = MAKE_REPORT.out.nonmatch_tsv     // channel: [ val(meta), path(tsv) ]
    agg_ref_type_tsv  = MAKE_REPORT.out.agg_ref_type_tsv // channel: [ val(meta), path(tsv) ]
    agg_subtype_tsv   = MAKE_REPORT.out.agg_subtype_tsv  // channel: [ val(meta), path(tsv) ]
    agg_flipflop_tsv  = MAKE_REPORT.out.agg_flipflop_tsv // channel: [ val(meta), path(tsv) ]
    tagged_bam        = MAKE_REPORT.out.tagged_bam       // channel: [ val(meta), path(bam) ]
    subtype_bams      = MAKE_REPORT.out.subtype_bams     // channel: [ val(meta), path(bam) ]
    subtype_bais      = MAKE_REPORT.out.subtype_bais     // channel: [ val(meta), path(bai) ]
    flipflop_bams     = MAKE_REPORT.out.flipflop_bams    // channel: [ val(meta), path(bam) ]
    flipflop_tsv      = MAKE_REPORT.out.flipflop_tsv     // channel: [ val(meta), path(tsv) ]
    aav_report_html   = MAKE_REPORT.out.aav_report_html  // channel: [ val(meta), path(html) ]
    aav_report_pdf    = MAKE_REPORT.out.aav_report_pdf   // channel: [ val(meta), path(pdf) ]

    versions = ch_versions                               // channel: [ versions.yml ]
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    THE END
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
