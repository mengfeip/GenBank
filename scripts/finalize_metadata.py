import pandas as pd
from datetime import datetime
import argparse

def get_update(query_date, ref_date):
    date_submitted = datetime.strptime(query_date, '%Y-%m-%d').toordinal()
    date_current = ref_date.toordinal()
    date_delta = date_current - date_submitted
    if date_delta <= 7:
        return '< 1 week'
    elif date_delta <= 14:
        return '1-2 weeks ago'
    elif date_delta <= 28:
        return '2-4 weeks ago'
    elif date_delta <= 90:
        return '1-3 months ago'
    elif date_delta <= 180:
        return '3-6 months ago'
    elif date_delta  <= 270:
        return '6-9 months ago'
    elif date_delta <= 365:
        return '9-12 months ago'
    elif date_delta <= 1095:
        return '1-3 years ago'
    elif date_delta <= 1826:
        return '3-5 years ago'
    else:
        return '> 5 years'

if __name__=="__main__":
    parser = argparse.ArgumentParser(
        description="Refine GenBank dataset metadata",
        formatter_class=argparse.ArgumentDefaultsHelpFormatter
    )

    parser.add_argument('--input-metadata', type=str, required=True, help="input metadata")
    parser.add_argument('--output-metadata', type=str, required=True, help="output final metadata")
    parser.add_argument('--output-update', type=str, required=True, help="output updates")
    args = parser.parse_args()

    df = pd.read_csv(args.input_metadata, sep='\t')
    df.loc[:,'database'] = "GenBank"
    df.loc[:,'note'] = df.loc[:,'strain']
    df.loc[:,'strain'] = df.loc[:,'accession']
    df.loc[:,'date_year'] = df.loc[:,'date'].replace(r"-.*","",regex=True)

    ref_date = datetime.now()
    for i in range(0, len(df)):
        if not pd.isna(df.loc[i,'date_submitted']):
            df.loc[i, 'update'] = get_update(df.loc[i, 'date_submitted'], ref_date)
    recent = ['< 1 week', '1-2 weeks ago']
    df_update = df[df['update'].isin(recent)]

    df_update.to_csv(args.output_update, sep='\t', index=False)
    df.to_csv(args.output_metadata, sep='\t', index=False)
