library(dplyr)
library(tidyr)
library(glmmTMB)
library(DHARMa)
library(emmeans)
library(easystats)
source("Analysis_Experiment2_AdaptiveBenefit/Experiment2_Functions.R")


# Load dataframes ---------------------------------------------------------

dat_for <- read.csv("Model_Output_Processed/IndividualVariationWaggleDance_Experiment2_Output_Foragers.csv")
str(dat_for)

# Adding Model ID and Food density ----------------------------------------

dat_for <- clean_up_data(dat_for)
str(dat_for)

# Converting to longform ----------------------------------

# Forager dataset
forg <- dat_for %>% 
  group_by(model, food_dens, day) %>% 
  gather("par", "value", c(median.foraging.distance:sd.dance.intensity.for))

# Subsetting dataframes for specific output parameters
yield_for_mean <- forg %>% filter(par == "mean.forager.yield")
fordist_median <- forg %>% filter(par == "median.foraging.distance")
search_for_mean <- forg %>% filter(par == "mean.search.time.for")
dance_for_mean <- forg %>% filter(par == "mean.dance.time.for")
dance_for_sd <- forg %>% filter(par == "sd.dance.time.for")


# Statistical Comparison --------------------------------------------------
# The statistical comparison will be done on the original dataset with individual values per day per run.
# The model will be a (G)LMM with the particular dance parameter value as response, 
# interaction between model and food density as predictor and Day nested within Run as the random effect


# 1. Median foraging distance ------------------------------------------------

# 1.1 LMM for median foraging distance ------------------------------------
lmm_fordist <- glmmTMB(value~food_dens*model + (1|simulation/day), data = fordist_median, family = gaussian(link="identity"))
# There is a warning about giveCsparse has been deprecated, but this is harmless: 
# https://stackoverflow.com/questions/67040472/warning-in-every-model-of-glmmtmb-givecsparse
# Testing Assumptions
simp <- simulateResiduals(fittedModel = lmm_fordist, n = 100)
plot(simp)
# The deviation in QQ plot is not significant from a dispersion test (but it is from a KS test). Overall it follows the straighline quite well
# The residuals versus predicted plot shows very very slight skew towards the end
testDispersion(simp)
# Dispersaion value is 1.0005. Well-fitted model

summary(lmm_fordist)
# There are multiple significant interaction terms, indicating that the models don't respond similarly


# 1.2 Marginal means for median foraging distance -------------------------
em_fordist <- emmeans(lmm_fordist, pairwise ~ model|food_dens)
em_fordist
emmip(lmm_fordist, food_dens~model)
# At low food density, model 1 and 4 are similar, and lower distances than model 2 and 3
# At medium food density, all 4 models are similar.
# At high food density, all 4 models are similar
# (Assuming higher median foraging distance is better)

margm_fordist <- em_fordist$emmeans %>% 
  format_table() %>% 
  mutate(CL = paste("[",lower.CL , "-", upper.CL, "]"), Par="Median Foraging Distance", 
         Diff_Labels = c("a","b","b","a", "a","a","a","a", "a","a","a","a")) %>% 
  select(Par, food_dens, model, everything())
contrasts_fordist <- em_fordist$contrasts %>% 
  format_table() %>% 
  mutate(Par="Median Foraging Distance")%>% 
  select(Par, food_dens, contrast, everything())


# 2. Mean Yield per Forager ------------------------------------------------

# 2.1 LMM for Mean Yield per Forager ------------------------------------
lmm_yield <- glmmTMB(value~food_dens*model + (1|simulation/day), data = yield_for_mean, family = gaussian(link="identity"))
# Ignoring warning message about Na function evaluation
# Testing Assumptions
simp <- simulateResiduals(fittedModel = lmm_yield, n = 100)
plot(simp)
# The deviation in QQ plot is not significant from a dispersion test (but it is from a KS test). Overall it follows the straighline quite well
# The residuals versus predicted plot shows very slight skew in the beginning
testDispersion(simp)
# Dispersion value is 1.0006. Well-fitted model

summary(lmm_yield)
# There are multiple significant interaction terms

# 2.2 Marginal means for Mean Yield per Forager -------------------------
em_yield <- emmeans(lmm_yield, pairwise ~ model|food_dens)
em_yield
emmip(lmm_yield, food_dens~model)
# At low food density, all models are the same
# At medium food density, Model 3 and 4 provides significantly higher yield per forager than other 2 models.
# At high food density, all models with individual variation are statistically similar and better than the null model

margm_yield <- em_yield$emmeans %>% 
  format_table() %>% 
  mutate(CL = paste("[",lower.CL , "-", upper.CL, "]"), Par="Mean Forager Yield", 
         Diff_Labels = c("a","a","a","a", "a","a","b","b", "a","b","b","b")) %>% 
  select(Par, food_dens, model, everything())
contrasts_yield <- em_yield$contrasts %>% 
  format_table() %>% 
  mutate(Par="Mean Forager Yield")%>% 
  select(Par, food_dens, contrast, everything())


# 3. Mean Search Time ------------------------------------------------

# 3.1 LMM for Mean Search Time ------------------------------------
lmm_search <- glmmTMB(value~food_dens*model + (1|simulation/day), data = search_for_mean, family = gaussian(link="identity"))
# Testing Assumptions
simp <- simulateResiduals(fittedModel = lmm_search, n = 100)
plot(simp)
# Virtually the same as the other models
# The deviation in QQ plot is not significant from a dispersion test (but it is from a KS test). Overall it follows the straighline quite well
# The residuals versus predicted plot shows very slight skew in the beginning
testDispersion(simp)
# Dispersion value is 1.0007. Well-fitted model

summary(lmm_search)
# There are many significant interaction terms

# 3.2 Marginal means for Mean Search Time -------------------------
em_search <- emmeans(lmm_search, pairwise ~ model|food_dens)
em_search
emmip(lmm_search, food_dens~model)
# At low density, model 1 and 4 are same and have lower search time
# At medium food density all 4 models are the same
# At high food density models 2 ,3,4 are similar. And model 2 is slightly better than model 1 and model 3 and 4 being the same as model 1


margm_search <- em_search$emmeans %>% 
  format_table() %>% 
  mutate(CL = paste("[",lower.CL , "-", upper.CL, "]"), Par="Mean Search Time", 
         Diff_Labels = c("a","b","b","a", "a","a","a","a", "a","b","ab","ab")) %>% 
  select(Par, food_dens, model, everything())
contrasts_search <- em_search$contrasts %>% 
  format_table() %>% 
  mutate(Par="Mean Search Time")%>% 
  select(Par, food_dens, contrast, everything())


# 4. Mean Dance Activity ------------------------------------------------

# 4.1 LMM for Mean Dance Activity ------------------------------------
lmm_dancemean <- glmmTMB(value~food_dens*model + (1|simulation/day), data = dance_for_mean, family = gaussian(link="identity"))
# Testing Assumptions
simp <- simulateResiduals(fittedModel = lmm_dancemean, n = 100)
plot(simp)
# Virtually the same as the other models
# The deviation in QQ plot is not significant from a dispersion test (but it is from a KS test). Overall it follows the straighline quite well
# The residuals versus predicted plot shows very slight skew in the beginning
testDispersion(simp)
# Dispersaion value is 1.0007. Well-fitted model

summary(lmm_dancemean)
# There are multiple significant interaction terms

# 4.2 Marginal means for Mean Dance Activity -------------------------
em_dancemean <- emmeans(lmm_dancemean, pairwise ~ model|food_dens)
em_dancemean
emmip(lmm_dancemean, food_dens~model)
# At low food density, model 1 has the highest dance activity. 2 and 3 have similar levels and 4 has the lowest
# At medium food density, models 1 and 2 are the same, 3 is the same as 1 but higher than 2 and 4 is the least
# At high food density, 2 and 3 are similar and higher than 1. Model 4 is lower than all 3
# Model 4 activity at medium and high food density are quite similar

margm_dancemean <- em_dancemean$emmeans %>% 
  format_table() %>% 
  mutate(CL = paste("[",lower.CL , "-", upper.CL, "]"), Par="Mean Dance Activity", 
         Diff_Labels = c("a","b","b","c", "ab","a","b","c", "a","b","b","c")) %>% 
  select(Par, food_dens, model, everything())
contrasts_dancemean <- em_dancemean$contrasts %>% 
  format_table() %>% 
  mutate(Par="Mean Dance Activity")%>% 
  select(Par, food_dens, contrast, everything())

# 5. Mean Dance Activity Variation ------------------------------------------------

# 5.1 LMM for Mean Dance Activity Variation ------------------------------------
lmm_dancesd <- glmmTMB(value~food_dens*model + (1|simulation/day), data = dance_for_sd, family = gaussian(link="identity"))
# Testing Assumptions
simp <- simulateResiduals(fittedModel = lmm_dancesd, n = 100)
plot(simp)
# Virtually the same as the other models
# The deviation in QQ plot is not significant from a dispersion test (but it is from a KS test). Overall it follows the straighline quite well
# The residuals versus predicted plot shows very slight skew in the beginning
testDispersion(simp)
# Dispersaion value is 1.0006. Well-fitted model

summary(lmm_dancesd)
# There are many significant interaction effects

# 5.2 Marginal means for Mean Dance Activity Variation -------------------------
em_dancesd <- emmeans(lmm_dancesd, pairwise ~ model|food_dens)
em_dancesd
emmip(lmm_dancesd, food_dens~model)
# At low food density and high food density, model 1 is worse than 2 which is worse than 4 which is worse than 3
# At medium food density, model 1 = model 2 < model 4 < model 3

margm_dancesd <- em_dancesd$emmeans %>% 
  format_table() %>% 
  mutate(CL = paste("[",lower.CL , "-", upper.CL, "]"), Par="Mean Dance Activity Variation", 
         Diff_Labels = c("a","b","c","d", "a","a","b","c", "a","b","c","d")) %>% 
  select(Par, food_dens, model, everything())
contrasts_dancesd <- em_dancesd$contrasts %>% 
  format_table() %>% 
  mutate(Par="Mean Dance Activity Variation")%>% 
  select(Par, food_dens, contrast, everything())


# Output marginal means and contrasts -------------------------------------
margm <- rbind(margm_fordist, margm_yield, margm_search, margm_dancemean, margm_dancesd)
contrasts <- rbind(contrasts_fordist, contrasts_yield, contrasts_search, contrasts_dancemean, contrasts_dancesd)

write.csv(margm, "Analysis_Experiment2_AdaptiveBenefit/Experiment2_OutputSummary_MarginalMeans.csv", row.names = F)
write.csv(contrasts, "Analysis_Experiment2_AdaptiveBenefit/Experiment2_OutputSummary_Contrasts.csv", row.names = F)
