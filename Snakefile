from snakemake.utils import min_version as min_snakemake_version

min_snakemake_version(
    "7.7.0"
)  # Snakemake 7.7.0 introduced `retries` directive used in fetch-sequences


configfile: "config/config.yaml"


rule all:
    input:
        dataset="data/genbank.ndjson",
        sequence="results/sequences.fasta",
        metadata="results/metadata_GenBank.tsv",
        update="results/metadata_GenBank_update.tsv",
    output:
        dataset=f"data/genbank_$(date +%Y-%m-%d).ndjson",
        sequence=f"results/sequences_$(date +%Y-%m-%d).fasta",
        metadata=f"results/metadata_$(date +%Y-%m-%d).tsv",
    shell:
        """
        cp {input.dataset} {output.dataset}
        cp {input.sequence} {output.sequence}
        cp {input.metadata} {output.metadata}
        """


include: "rules/dataset_fetch.smk"
include: "rules/dataset_curate.smk"
include: "rules/nextclade_assign.smk"


if "custom_rules" in config:
    for rule_file in config["custom_rules"]:
        include: rule_file


rule clean_all:
    """
    Clean data and results directories
    """
    params:
        "data",
        "results",
    shell:
        """
        rm -rf {params}
        """
