import pandas as pd
import numpy as np

# Read CSVs
header = range(6)
columns = ["probability-modulator-modifier", "intensity-modulator-modifier", "[run number]",
           "day-counter", "get-list-daily-visitsp1", "get-list-daily-visitsp2",
           "get-list-daily-visitsp3", "get-list-daily-visitsp4", "get-list-daily-dances", "get-list-daily-turns"]

dat1 = pd.read_csv("IndividualVariationWaggleDance_SensitivityAnalysis Sensitivity-Analysis-table_Set1.csv", skiprows=header,
                  usecols=columns)
dat2 = pd.read_csv("IndividualVariationWaggleDance_SensitivityAnalysis Sensitivity-Analysis-table_Set2.csv", skiprows=header,
                  usecols=columns)

# Shortlist last 3 days of the simulation
dat1 = dat1.loc[dat1["day-counter"].isin([3, 4, 5])].sort_values(by=["probability-modulator-modifier", "intensity-modulator-modifier", '[run number]', "day-counter"])
dat2 = dat2.loc[dat2["day-counter"].isin([3, 4, 5])].sort_values(by=["probability-modulator-modifier", "intensity-modulator-modifier", '[run number]', "day-counter"])

# Create column for simulation number per model
dat1["simulation"] = np.tile(np.repeat(np.arange(1, 6, 1), 3), 80)
dat2["simulation"] = np.tile(np.repeat(np.arange(6, 11, 1), 3), 80)

# Combine CSVs
dat = pd.concat([dat1, dat2])
dat.sort_values(by=["probability-modulator-modifier", "intensity-modulator-modifier", 'simulation', "day-counter"], inplace=True)

# Convert str to list using a custom function
def str_to_list(patch_list_name):
    # Get patch column name
    patch_list = dat[patch_list_name]
    # Remove brackets at ends of string
    patch_list = patch_list.apply(lambda x: x.lstrip("[").rstrip("]"))
    # Split string up based on whitespace
    patch_list_2 = patch_list.str.split("[\s]")
    # Convert string to int
    patch_list_2 = patch_list_2.apply(lambda x: [int(y) for y in x])
    return patch_list_2


dat["patch1"] = str_to_list("get-list-daily-visitsp1")
dat["patch2"] = str_to_list("get-list-daily-visitsp2")
dat["patch3"] = str_to_list("get-list-daily-visitsp3")
dat["patch4"] = str_to_list("get-list-daily-visitsp4")
dat["dances"] = str_to_list("get-list-daily-dances")
dat["circuits"] = str_to_list("get-list-daily-turns")

# Remove unwanted columns
dat.drop(["[run number]", "get-list-daily-visitsp1", "get-list-daily-visitsp2",
          "get-list-daily-visitsp3", "get-list-daily-visitsp4",
          "get-list-daily-dances", "get-list-daily-turns"], axis=1, inplace=True)

# Explode lists into rows
dat_unpacked = dat.explode(["patch1", "patch2", "patch3", "patch4", "dances", "circuits"])

# Create column for agents
dat_unpacked["agent"] = np.tile(np.arange(1, 301, 1), 2400)

# Create column for day
dat_unpacked["day"] = np.tile(np.repeat(np.arange(1, 4, 1), 300), 800)

# Remove scouts
dat_unpacked = dat_unpacked[dat_unpacked["agent"].lt(271)]

# Sum the patch visits for each agent in each simulation in each model
consistent = dat_unpacked.groupby(["probability-modulator-modifier", "intensity-modulator-modifier", "simulation",
                                   "agent"]).agg({"patch1": ['sum'], "patch2": ['sum'], "patch3": ['sum'],
                                                  "patch4": ['sum']})

# Query for agents which have only 1 non-zero value (visited only one patch over 3 days])
consistent_agents = consistent[consistent.eq(0).sum(axis=1).eq(3)]

# Slice unpacked dataset based on row indices in the consistent_agents dataset
dat_unpacked.set_index(["probability-modulator-modifier", "intensity-modulator-modifier", "simulation", "agent"], inplace=True)
final = dat_unpacked[dat_unpacked.index.isin(consistent_agents.index.tolist())].copy()

# Create column for trips (so that individual patch columns can be removed)
final["trips"] = final.patch1 + final.patch2 + final.patch3 + final.patch4

# Clean up final dataframe by removing and reordering columns and resetting index
final.drop(["patch1", "patch2", "patch3", "patch4", "day-counter"], axis=1, inplace=True)
final.reset_index(inplace=True)
final = final.reindex(columns=["probability-modulator-modifier", "intensity-modulator-modifier", "simulation", "day", "agent", "trips", "dances", "circuits"])

# Output final CSV
final.to_csv("IndividualVariationWaggleDance_SensitivityAnalysis_Output.csv", index=False)