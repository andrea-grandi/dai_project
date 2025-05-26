# Simulations of individual variation in dance activity in honey bees
Code, Datasets and Analysis associated with the Agent-based model simulations of honey bee foraging behaviour incorporating individual variation in dance activity
This repository has everything needed to rerun the simulations. The repository contains the following folders and files (in the order they need to be run):
<ol>
  <li> Model Input Folder - This contains the R code to visualise different levels of variation in probability and intensity as well as illustrator files showing the   process opverview for foragers and scouts in the ABM
  <li> Model Code - This folder contains three folders
  <ol> 
    <li> ABM_NETLOGO - containing separate NETLOGO codes to run the ABMs for Experiment 1, Experiment 2 and the Sensitivity Analysis as described in the manuscript
    <li> ABM_NETLOGO_Output - the CSVs obtained directly from running the NETLOGO codes via the _'behaviourspace'_ tool (with the _'table'_ output format) in NETLOGO 
    <li> OutputCleanup_Python - python codes to clean up the output files obtained directly from NETLOGO
  </ol>
  <li> Model_Output_Processed - the processed CSV files obtained after cleaning up the output produced from NETLOGO using python. These are the CSVs on which the statsitical analysis is done
  <li> Analysis_Experiment1_Repeatability - R codes for analysing the data obtained from the simulations in Experiment 1 and the output (results, graphs) of the analysis
  <li> Analysis_Experiment2_AdaptiveBenefit - R codes for analysing the data obtained from the simulations in Experiment 2 and the output (results, graphs) of the analysis
  <li> Analysis_SensitivityAnalysis_Repeatability - R codes for analysing the data obtained from the sensitivity analysis and the output (results, graphs) of the analysis 
</ol>

## Rerunning the simulations
To rerun the simulations and the analysis, follow the process below:
<ol>
  <li> Open the NETLOGO code for an experiment of interest and use the _behaviourspace_ tool to run multiple simulations. Make sure to select the _table_ output.
  <ul> <li> For experiment 1, the behaviourspace code is set to run 100 simulations of each of the 4 models
       <li> For experiment 2, the behaviourspace code is set to run 20 simulations of each of the 12 model combinations
       <li> For the sensitivity analysis, the behaviourspace code is set to run 5 simulations of each of the 80 model combinations. When re-running the analysis, the random seed number must be changed. this can be done by selecting the edit option in the _behaviourspace_ tool and providing new seed numbers in the appropriate location.
   </ul>
   <li> Copy the CSVs output by NETLOGO into the same folder with python code and run the code to process the CSVs for analysis. Ensure that the CSVs are named as in the ABM_NETLOGO_Output folder or alternatively change the python code to match the names of the files
   <li> Copy the processed CSVs to the Model_Output_Processed folder and the run the R codes in the 'Analysis' folder linked to the particular experiment to perform the statistical analysis
</ol>
