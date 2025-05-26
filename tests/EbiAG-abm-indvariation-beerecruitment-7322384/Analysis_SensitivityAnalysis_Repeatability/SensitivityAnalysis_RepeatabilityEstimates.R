library(rptR)
library(dplyr)
set.seed(123456)

# Load dataframe ----------------------------------------------------------

dat <- read.csv("Model_Output_Processed/IndividualVariationWaggleDance_SensitivityAnalysis_Output.csv")
str(dat)

# Calculating repeatability estimates -------------------------------------

d <- dat %>% 
  nest_by(probability.modulator.modifier, intensity.modulator.modifier, simulation) %>% 
  summarise(rep_estimate = as.numeric(rpt(circuits~(1|agent), grname="agent", 
                                          datatype = "Gaussian", nboot=0,parallel = F, data=data)$R))


# Output repeatability estimates CSV --------------------------------------

write.csv(d, "Analysis_SensitivityAnalysis_Repeatability/SensitivityAnalysis_RepeatabilityEstimates.csv", row.names = F)


# Obtain mean repeatability estimates -------------------------------------
d_sum <- d %>% 
  group_by(probability.modulator.modifier, intensity.modulator.modifier) %>% 
  summarise(mean = mean(rep_estimate), sd = sd(rep_estimate))


# Adding values of the coef of var ----------------------------------------
# Probability CoV
prob_cv <- rep(c(0.019495161, 0.048385493, 0.087654577, 0.125995216, 0.172588423, 0.237123402, 0.309337967, 
                 0.390947449), each=10)
# Intensity CoV
int_cv <- rep(c(0.039359678, 0.073337167, 0.111861871, 0.148519297, 0.193038339, 0.221253684, 0.275027955, 
                0.307814144, 0.334566201, 0.3704586),8)

d_sum$prob_cv <- prob_cv
d_sum$int_cv <- int_cv


# Output mean repeatability estimates CSV ---------------------------------

write.csv(d_sum, "Analysis_SensitivityAnalysis_Repeatability/SensitivityAnalysis_RepeatabilityEstimates_Summary.csv", row.names = F)
