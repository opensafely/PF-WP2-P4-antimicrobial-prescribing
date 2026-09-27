import pandas as pd
from pathlib import Path
import config
from config import month_range
import argparse

# utilisation: python analysis/preprocess_combine_gz.py
# run : "python analysis/preprocess_combine_gz_Arnaud.py" in the terminal

start_dates = month_range(config.start, config.end) #Use this one to combine

#start_dates = ["2022-02-01", "2022-03-01"] # Here we used 2022 instead 2024 to have two years pre PF

dfs = []

for d in start_dates:
    file = Path(f"output/dataset_patients_{d}.csv.gz")

    if file.exists():
        df = pd.read_csv(file, low_memory=False) #df = pd.read_csv(file) seems to not work, i added "low_memory:False"
        dfs.append(df)

combined = pd.concat(dfs, ignore_index=True)

parser = argparse.ArgumentParser()
parser.add_argument(
    "--output",
    default="output/dataset_patients_combined.csv.gz",
    help="Output file path"
)

args = parser.parse_args()
combined.to_csv(args.output, index=False)
