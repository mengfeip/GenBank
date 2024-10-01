"""
This part of the workflow runs Nextclade for alignment and clustering.

Expects input as:
    sequences = "results/sequences.fasta"
    metadata = "data/metadata_subset.tsv"

Generates final output as:
    final = "results/metadata_GenBank.tsv"
"""


rule download_mpxv_dataset:
    output:
        temp("data/mpxv_main.zip"),
    shell:
        """
        nextclade dataset get --name MPXV \
            --output-zip {output}
        """


rule download_cladeI_dataset:
    output:
        temp("data/mpxv_cladeI.zip"),
    shell:
        """
        nextclade dataset get --name="nextstrain/mpox/clade-i" \
            --output-zip {output}
        """


rule download_hMPXV_dataset:
    output:
        temp("data/hmpxv.zip"),
    shell:
        """
        nextclade dataset get --name hMPXV \
            --output-zip {output}
        """


rule align:
    input:
        sequences="results/sequences.fasta",
        dataset="data/hmpxv.zip",
    params:
        translations=lambda w: "data/translations/{gene}.fasta",
    output:
        alignment="data/alignment.fasta",
        insertions="data/insertions.csv",
        translations="data/translations.zip",
    threads: 4
    shell:
        """
        nextclade run -D {input.dataset} -j {threads} \
            --retry-reverse-complement \
            --output-fasta {output.alignment} \
            --output-translations {params.translations} \
            --output-insertions {output.insertions} {input.sequences}
        zip -rj {output.translations} data/translations
        """


rule nextclade_main:
    input:
        sequences="results/sequences.fasta",
        dataset="data/mpxv_main.zip",
    output:
        temp("data/nextclade_main.tsv"),
    threads: 4
    shell:
        """
        nextclade run -D {input.dataset} -j {threads} \
            --output-tsv {output} {input.sequences} \
            --retry-reverse-complement
        """


rule nextclade_cladeI:
    input:
        sequences="results/sequences.fasta",
        dataset="data/mpxv_cladeI.zip",
    output:
        temp("data/nextclade_cladeI.tsv"),
    threads: 4
    shell:
        """
        nextclade run -D {input.dataset} -j {threads} \
            --output-tsv {output} {input.sequences} \
            --retry-reverse-complement
        """


rule refine_nextclade:
    input:
        allclades="data/nextclade_main.tsv",
        cladeI="data/nextclade_cladeI.tsv",
    output:
        cladeI="data/nextclade_Clade-I.tsv",
        cladeII="data/nextclade_Clade-II.tsv",
        final="data/nextclade.tsv",
    shell:
        """
        python3 scripts/refine_nextclade.py \
	          --input-cladeI {input.cladeI} \
            --input-all {input.allclades} \
	          --output-cladeI {output.cladeI}
	      cp {input.allclades} {output.cladeII}
	      cp {input.allclades} {output.final}
        """


rule join_metadata:
    input:
        nextclade="data/nextclade.tsv",
        metadata="data/metadata_subset.tsv",
        nextclade_field_map=config["nextclade"]["field_map"],
    params:
        id_field=config["curate"]["id_field"],
        nextclade_id_field=config["nextclade"]["id_field"],
    output:
        metadata="results/metadata.tsv",
        final="results/metadata_GenBank.tsv",
        update="results/metadata_GenBank_update.tsv",
    shell:
        """
        export SUBSET_FIELDS=`awk 'NR>1 {{print $1}}' {input.nextclade_field_map} | tr '\n' ',' | sed 's/,$//g'`
        csvtk -tl cut -f $SUBSET_FIELDS \
            {input.nextclade} \
        | csvtk -tl rename2 \
            -F \
            -f '*' \
            -p '(.+)' \
            -r '{{kv}}' \
            -k {input.nextclade_field_map} \
        | tsv-join -H \
            --filter-file - \
            --key-fields {params.nextclade_id_field} \
            --data-fields {params.id_field} \
            --append-fields '*' \
            --write-all ? \
            {input.metadata} \
        | tsv-select -H --exclude {params.nextclade_id_field} \
            > {output.metadata}
        python3 scripts/finalize_metadata.py \
	          --input-metadata {output.metadata} \
	          --output-metadata {output.final} \
	          --output-update {output.update}
        """
