process MAKE_REPORT {
    tag "$meta.id"
    label 'process_medium'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        "${params.container_repo}/laava${params.container_version}" :
        "${params.container_repo}/laava${params.container_version}" }"

    input:
    tuple val(meta), path(reference_names), path(mapped_reads)
    path vector_annotation
    val itr_label_1
    val itr_label_2
    val mitr_label
    val vector_type
    val target_gap_threshold
    val max_allowed_outside_vector
    val max_allowed_missing_flanking
    val min_supp_joint_coverage
    val flipflop_name
    path flipflop_fa

    output:
    tuple val(meta), path("${prefix}.metadata.tsv")                    , emit: metadata_tsv
    tuple val(meta), path("${prefix}.alignments.tsv.gz")              , emit: alignments_tsv
    tuple val(meta), path("${prefix}.per_read.tsv.gz")                , emit: per_read_tsv
    tuple val(meta), path("${prefix}.nonmatch.tsv.gz")                , emit: nonmatch_tsv
    tuple val(meta), path("${prefix}.agg_ref_type.tsv")               , emit: agg_ref_type_tsv
    tuple val(meta), path("${prefix}.agg_subtype.tsv")                , emit: agg_subtype_tsv
    tuple val(meta), path("${prefix}.flipflop.tsv.gz")       , optional: true, emit: flipflop_tsv
    tuple val(meta), path("${prefix}.agg_flipflop.tsv")      , optional: true, emit: agg_flipflop_tsv
    tuple val(meta), path("${prefix}.tagged.bam")                     , emit: tagged_bam
    tuple val(meta), path("${prefix}.*.tagged.sorted.bam")            , emit: subtype_bams
    tuple val(meta), path("${prefix}.*.tagged.sorted.bam.bai")        , emit: subtype_bais
    tuple val(meta), path("${prefix}.flipflop-*.bam")        , optional: true, emit: flipflop_bams
    tuple val(meta), path("${prefix}_AAV_report.html")                , emit: aav_report_html
    tuple val(meta), path("${prefix}_AAV_report.pdf")                 , emit: aav_report_pdf
    path "versions.yml"                                                , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    prefix = task.ext.prefix ?: "${meta.id}"
    
    // Handle optional flipflop input
    def ff_fa_arg = flipflop_fa ? flipflop_fa.name != "NO_FILE" ? "$flipflop_fa" : "" : ""
    
    """
    # Set up writable temporary directories for R/pandoc
    export TMPDIR=\$(pwd)/tmp
    export TMP=\$(pwd)/tmp  
    export TEMP=\$(pwd)/tmp
    mkdir -p \$TMPDIR
    
    # Set up fontconfig cache directory
    export FONTCONFIG_PATH=\$(pwd)/fontconfig
    mkdir -p \$FONTCONFIG_PATH
    
    # Set R environment variables
    export R_LIBS_USER=\$(pwd)/R_libs
    mkdir -p \$R_LIBS_USER
    
    make_report.sh \\
        $args \\
        "${prefix}" \\
        "${meta.id}" \\
        "${workflow.manifest.version}" \\
        "${reference_names}" \\
        "${mapped_reads}" \\
        "${vector_annotation}" \\
        "${itr_label_1}" \\
        "${itr_label_2}" \\
        "${mitr_label}" \\
        "${vector_type}" \\
        "${target_gap_threshold}" \\
        "${max_allowed_outside_vector}" \\
        "${max_allowed_missing_flanking}" \\
        "${min_supp_joint_coverage}" \\
        "${flipflop_name}" \\
        "${ff_fa_arg}" \\
        "."

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        laava: \$(echo "${workflow.manifest.version}")
        r-base: \$(echo \$(R --version 2>&1) | sed 's/^.*R version //; s/ .*\$//')
        samtools: \$(echo \$(samtools --version 2>&1) | sed 's/^.*samtools //; s/Using.*\$//')
    END_VERSIONS
    """

    stub:
    def args = task.ext.args ?: ''
    prefix = task.ext.prefix ?: "${meta.id}"
    """
    touch ${prefix}.metadata.tsv
    touch ${prefix}.alignments.tsv.gz
    touch ${prefix}.per_read.tsv.gz
    touch ${prefix}.nonmatch.tsv.gz
    touch ${prefix}.agg_ref_type.tsv
    touch ${prefix}.agg_subtype.tsv
    touch ${prefix}.flipflop.tsv.gz
    touch ${prefix}.agg_flipflop.tsv
    touch ${prefix}.tagged.bam
    touch ${prefix}.full.tagged.sorted.bam
    touch ${prefix}.full.tagged.sorted.bam.bai
    touch ${prefix}.flipflop-test.bam
    touch ${prefix}_AAV_report.html
    touch ${prefix}_AAV_report.pdf

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        laava: \$(echo "${workflow.manifest.version}")
        r-base: \$(echo \$(R --version 2>&1) | sed 's/^.*R version //; s/ .*\$//')
        samtools: \$(echo \$(samtools --version 2>&1) | sed 's/^.*samtools //; s/Using.*\$//')
    END_VERSIONS
    """
}
