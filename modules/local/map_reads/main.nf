process MAP_READS {
    tag "$meta.id"
    label 'process_medium'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        "${params.container_repo}/laava${params.container_version}" :
        "${params.container_repo}/laava${params.container_version}" }"

    input:
    tuple val(meta), path(reads)
    path vector_fa
    path packaging_fa
    path host_fa
    val repcap_name
    val helper_name
    val lambda_name

    output:
    tuple val(meta), path("${prefix}.reference_names.tsv"), path("${prefix}.sort_by_name.bam"), emit: mapped_name_bam
    tuple val(meta), path("${prefix}.sort_by_pos.bam"), path("${prefix}.sort_by_pos.bam.bai")  , emit: mapped_pos_bam
    path "versions.yml"                                                                        , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    prefix = task.ext.prefix ?: "${meta.id}"
    
    // Handle optional inputs
    def packaging_fa_arg = packaging_fa ? packaging_fa.name != "NO_FILE" ? "$packaging_fa" : "" : ""
    def host_fa_arg = host_fa ? host_fa.name != "NO_FILE2" ? "$host_fa" : "" : ""
    
    """
    map_reads.sh \\
        $args \\
        ${prefix} \\
        "${reads}" \\
        "${vector_fa}" \\
        "${packaging_fa_arg}" \\
        "${host_fa_arg}" \\
        "${repcap_name}" \\
        "${helper_name}" \\
        "${lambda_name}"

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        laava: \$(echo "${workflow.manifest.version}")
        minimap2: \$(minimap2 --version 2>&1)
        samtools: \$(echo \$(samtools --version 2>&1) | sed 's/^.*samtools //; s/Using.*\$//')
    END_VERSIONS
    """

    stub:
    def args = task.ext.args ?: ''
    prefix = task.ext.prefix ?: "${meta.id}"
    """
    touch ${prefix}.reference_names.tsv
    touch ${prefix}.sort_by_name.bam
    touch ${prefix}.sort_by_pos.bam
    touch ${prefix}.sort_by_pos.bam.bai

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        laava: \$(echo "${workflow.manifest.version}")
        minimap2: \$(minimap2 --version 2>&1)
        samtools: \$(echo \$(samtools --version 2>&1) | sed 's/^.*samtools //; s/Using.*\$//')
    END_VERSIONS
    """
}
