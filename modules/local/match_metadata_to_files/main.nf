process MATCH_METADATA_TO_FILES {
    tag "$meta.id"
    label 'process_single'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/python:3.11.0' :
        'biocontainers/python:3.11.0' }"

    input:
    tuple val(meta), path(sample_in_metadata)
    path sample_folder

    output:
    tuple val(meta), path("metadata_with_paths.tsv"), emit: metadata
    path "versions.yml"                              , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    match_metadata_to_files.py \\
        $args \\
        ${sample_in_metadata} \\
        ${sample_folder} \\
        > metadata_with_paths.tsv

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        python: \$(python --version | sed 's/Python //g')
    END_VERSIONS
    """

    stub:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    touch metadata_with_paths.tsv

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        python: \$(python --version | sed 's/Python //g')
    END_VERSIONS
    """
}
