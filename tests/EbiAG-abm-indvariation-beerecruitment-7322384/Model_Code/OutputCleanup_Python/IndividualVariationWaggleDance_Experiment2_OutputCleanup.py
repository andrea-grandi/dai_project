# %%
import pandas as pd
import numpy as np

# Read CSVs
header = range(6)
columns = ["probability-modulator-on", "intensity-modulator-on", "density-food", "[run number]", "day-counter", "nest-energy",
           "get-median-foraging-distance", "get-mean-forager-yield", "get-mean-search-timer-for-new", "get-sd-search-timer-for-new",
           "get-mean-dance-timer-for-new", "get-sd-dance-timer-for-new", "get-mean-idle-timer-for-new", "get-sd-idle-timer-for-new",
           "get-sum-idle-timer-for-new", "get-mean-danceprob-for-new", "get-sd-danceprob-for-new", "get-mean-danceinten-for-new",
           "get-sd-danceinten-for-new", "get-mean-scout-yield", "get-mean-search-timer-sc-new", "get-sd-search-timer-sc-new",
           "get-mean-dance-timer-sc-new", "get-sd-dance-timer-sc-new", "get-mean-danceprob-sc-new", "get-sd-danceprob-sc-new",
           "get-mean-danceinten-sc-new", "get-sd-danceinten-sc-new"]

dat1 = pd.read_csv("IndividualVariationWaggleDance_Experiment2 Exp2_4Models_3FoodDens_20Runs_Set1.csv", skiprows=header,
                  usecols=columns)
dat2 = pd.read_csv("IndividualVariationWaggleDance_Experiment2 Exp2_4Models_3FoodDens_20Runs_Set2.csv", skiprows=header,
                  usecols=columns)


# Remove first 3 days and sort dataframes
dat1 = dat1.loc[dat1["day-counter"].gt(3)].sort_values(by=["probability-modulator-on", "intensity-modulator-on", "density-food", '[run number]', "day-counter"])
dat2 = dat2.loc[dat2["day-counter"].gt(3)].sort_values(by=["probability-modulator-on", "intensity-modulator-on", "density-food", '[run number]', "day-counter"])

# Create column for simulation number per model
dat1["simulation"] = np.tile(np.repeat(np.arange(1, 21, 1), 48), 12)
dat2["simulation"] = np.tile(np.repeat(np.arange(21, 41, 1), 48), 12)

# Combine CSVs
dat = pd.concat([dat1, dat2])
dat.sort_values(by=["probability-modulator-on", "intensity-modulator-on", "density-food", 'simulation', "day-counter"], inplace=True)

# Add day numbering starting from 1
dat["day"] = np.tile(np.arange(1, 49, 1), 480)

# Drop unwanted columsn
dat.drop(["[run number]", "day-counter"], axis=1, inplace=True)

# Rename unwieldy column names
dat.columns = dat.columns.str.replace("get-", "")
dat.columns = dat.columns.str.replace("-new", "")
dat.columns = dat.columns.str.replace("timer", "time")
dat.columns = dat.columns.str.replace("danceinten", "dance-intensity")
dat.columns = dat.columns.str.replace("danceprob", "dance-probability")

# Reorder columns
cols = ["probability-modulator-on", "intensity-modulator-on", "density-food", 'simulation', "day"]
dat = dat[cols + [c for c in dat.columns if c not in cols]]

# Create separate datasets for foragers and scouts
d = dat[cols + ["nest-energy", "median-foraging-distance"]]
d_forager = dat.loc[:, dat.columns.str.contains('for')].copy()
d_forager.drop("median-foraging-distance", axis=1, inplace=True)
d_scout = dat.loc[:, dat.columns.str.contains('sc')].copy()

# Add common columns to forager and scout datasets
forager = pd.concat([d, d_forager], axis=1)
scout = pd.concat([d, d_scout], axis=1)

# Output CSVs
forager.to_csv("IndividualVariationWaggleDance_Experiment2_Output_Foragers.csv", index=False)
scout.to_csv("IndividualVariationWaggleDance_Experiment2_Output_Scouts.csv", index=False)
