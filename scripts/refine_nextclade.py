import pandas as pd
import argparse

if __name__=="__main__":
    parser = argparse.ArgumentParser(
        description="Refine Clade-I nextclade results",
        formatter_class=argparse.ArgumentDefaultsHelpFormatter
    )

    parser.add_argument('--input-all', type=str, required=True, help="input all nextclade results for all clades")
    parser.add_argument('--input-cladeI', type=str, required=True, help="input nextclade results for clade-I")
    parser.add_argument('--output-cladeI', type=str, required=True, help="output nextclade results for clade-I")
    args = parser.parse_args()

    nc1 = pd.read_csv(args.input_cladeI, sep='\t')
    nc2 = pd.read_csv(args.input_all, sep='\t')
    cladeI = ["I","Ia","Ib"]
    df1 = nc1[nc1['clade'].isin(cladeI)]
    df2 = nc2[nc2['clade'].isin(cladeI)]
    seq = df2["seqName"].tolist()
    df = df1[df1['seqName'].isin(seq)]
    df = df.assign(lineage="")

    df.to_csv(args.output_cladeI, sep='\t', index=False)
