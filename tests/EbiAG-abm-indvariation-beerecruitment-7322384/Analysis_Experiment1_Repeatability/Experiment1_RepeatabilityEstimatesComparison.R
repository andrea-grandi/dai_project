library(rptR)
library(dplyr)
library(betareg)
library(emmeans)
library(easystats)

# Load dataset ------------------------------------------------------------

dat <- read.csv("Model_Output_Processed/IndividualVariationWaggleDance_Experiment1_Output.csv")
# Need to calculate rep estimates by grouping the dataset


# Calculating repeatability estimates -------------------------------------
# nest_by model and simulation. And then call the rpt function. 
# nest_by is used so that the dataframe is subset rowwise and this subset dataframe is availablee for the summarise function 
# (group_by does not make this available)
d <- dat %>% 
  mutate(model = paste("Model", model, sep="_")) %>% 
  nest_by(model, simulation) %>% 
  summarise(rep_estimate = as.numeric(rpt(circuits~(1|agent), grname="agent", 
                                          datatype = "Gaussian", nboot=0,parallel = F, data=data)$R))


# Output repeatability estimates CSV ------------------------------------------

write.csv(d, "Analysis_Experiment1_Repeatability/RepeatabilityEstimates_4Models_100Runs.csv", row.names = F)


# Obtain summary statistics ------------------------------------

d_sum <- d %>% 
  group_by(model) %>% 
  summarise(mean_rep = mean(rep_estimate), sd_rep = sd(rep_estimate))


# Output summary CSV ------------------------------------------------------

write.csv(d_sum, "Analysis_Experiment1_Repeatability/RepeatabilityEstimates_4Models_100Runs_Summary.csv", row.names = F)


# Statistical Analysis ----------------------------------------------------

hist(d$rep_estimate)
# Bi-modal distribution with lower and upper bounds [0,1]. Using beta regression

# betareg values must lie in between 0 and 1 and can't include 0.
# Modifying based on info in package vignette
# Furthermore, if y also assumes the extremes 0 and 1, a useful transformation in practice is (y * (n - 1) + 0.5)/n where n is the sample size (Smithson and Verkuilen 2006).
y.transf.betareg <- function(y){
  n.obs <- sum(!is.na(y))
  (y * (n.obs - 1) + 0.5) / n.obs
}

b.mod <- betareg(y.transf.betareg(rep_estimate)~model, data = d)
plot(b.mod, which=1:4)
plot(b.mod, which=5)
# Cooks plot is fine, no major outliers.
# leverages vs predicted values also looks fine. Homoscedasticity is good, some 0 values are obvious
# Half normal plot of residuals also seems much much better. Some outlier values at the end (likely from model 3)
summary(b.mod)
# Similar results, although the estimates are different

b.mod_em <- emmeans(b.mod,"model")
pairs(b.mod_em)


# Analysis output CSV -----------------------------------------------------

# Output table
marg_em <- b.mod_em %>% 
  format_table(digits = 4,ci_digits = 4) %>% 
  mutate(Par="RepeatabilityEstimates", CL = paste("[",asymp.LCL , "-", asymp.UCL, "]"),)%>% 
  select(Par, everything())
contrasts_em <- pairs(b.mod_em) %>% 
  format_table(digits = 3,ci_digits = 3) %>% 
  mutate(Par="RepeatabilityEstimates")%>% 
  select(Par, everything())

write.csv(marg_em, "Analysis_Experiment1_Repeatability/RepeatabilityEstimates_4Models_100Runs_MarginalMeans.csv", row.names = F)
write.csv(contrasts_em, "Analysis_Experiment1_Repeatability/RepeatabilityEstimates_4Models_100Runs_Contrasts.csv", row.names = F)
