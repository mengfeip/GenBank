"""
This part of the workflow fetches sequences from source dataset.

Downloads dataset package from NCBI Virus GenBank.

Generates final output as:
    sequences_ndjson = "data/sequences.ndjson"
"""


rule fetch_ncbi_dataset:
    params:
        ncbi_taxon_id=config.get("ncbi_taxon_id",""),
        accession=config.get("accession",""),
        accession_list=config.get("accession_list",""),
        geo_location=config.get("geo_location",""),
        release_date=config.get("release_date",""),
    output:
        dataset_package=temp("data/ncbi_dataset.zip"),
    retries: 5  # Requires snakemake 7.7.0 or later
    shell:
        """
        scripts/datasets download virus genome {params.ncbi_taxon_id} \
            {params.accession} \
            {params.accession_list} \
            {params.geo_location} \
            {params.release_date} \
            --no-progressbar \
            --filename {output.dataset_package}
        """


rule extract_ncbi_sequences:
    input:
        dataset_package="data/ncbi_dataset.zip",
    output:
        ncbi_dataset_sequences=temp("data/ncbi_dataset_sequences.fasta"),
    shell:
        """
        unzip -jp {input.dataset_package} \
            ncbi_dataset/data/genomic.fna > {output.ncbi_dataset_sequences}
        """


def _get_ncbi_mnemonics(wildcards) -> str:
    """
    Return list of NCBI Dataset report field mnemonics for fields of dataset report.
    The column names in the output TSV are different from the mnemonics.
    See NCBI Dataset docs for full list of available fields and their column.
    https://www.ncbi.nlm.nih.gov/datasets/docs/v2/reference-docs/command-line/dataformat/tsv/dataformat_tsv_virus-genome/#fields
    """
    fields = [
        "accession",
        "sourcedb",
        "isolate-lineage",
        "geo-region",
        "geo-location",
        "isolate-collection-date",
        "release-date",
        "update-date",
        "length",
        "host-name",
        "isolate-lineage-source",
        "bioprojects",
        "biosample-acc",
        "sra-accs",
        "submitter-names",
        "submitter-affiliation",
    ]
    return ",".join(fields)


rule format_ncbi_report:
    input:
        dataset_package="data/ncbi_dataset.zip",
        ncbi_field_map=config["ncbi_field_map"],
    params:
        fields_to_include=_get_ncbi_mnemonics,
    output:
        ncbi_dataset_tsv=temp("data/ncbi_dataset_report.tsv"),
    shell:
        """
        scripts/dataformat tsv virus-genome \
            --package {input.dataset_package} \
            --fields {params.fields_to_include:q} \
            | csvtk -tl rename2 -F -f '*' -p '(.+)' -r '{{kv}}' -k {input.ncbi_field_map} \
            | csvtk -tl mutate -f genbank_accession_rev -n genbank_accession -p "^(.+?)\." \
            | csvtk -tl mutate2 -n note -e "''" --after strain \
            | csvtk -tl mutate2 -n date_year -e "''" --after collected \
            | tsv-select -H -f genbank_accession --rest last \
            > {output.ncbi_dataset_tsv}
        """


rule format_ncbi_dataset:
    input:
        ncbi_dataset_sequences="data/ncbi_dataset_sequences.fasta",
        ncbi_dataset_tsv="data/ncbi_dataset_report.tsv",
    output:
        ndjson="data/genbank.ndjson",
    shell:
        """
        augur curate passthru \
            --metadata {input.ncbi_dataset_tsv} \
            --fasta {input.ncbi_dataset_sequences} \
            --seq-id-column genbank_accession_rev \
            --seq-field sequence \
            --unmatched-reporting warn \
            --duplicate-reporting warn \
            > {output.ndjson}
        """


def _get_all_sources(wildcards):
    return [f"data/{source}.ndjson" for source in config["sources"]]


rule fetch_all_sequences:
    input:
        all_sources=_get_all_sources,
    output:
        sequences_ndjson="data/sequences.ndjson",
    shell:
        """
        cat {input.all_sources} > {output.sequences_ndjson}
        """
