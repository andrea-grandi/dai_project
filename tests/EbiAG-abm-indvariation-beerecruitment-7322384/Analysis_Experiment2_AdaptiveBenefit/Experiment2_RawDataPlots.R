library(dplyr)
library(tidyr)
source("Analysis_Experiment2_AdaptiveBenefit/Experiment2_Functions.R")

# Load dataframes ---------------------------------------------------------

dat_for <- read.csv("Model_Output_Processed/IndividualVariationWaggleDance_Experiment2_Output_Foragers.csv")
str(dat_for)

# Adding Model ID and Food density ----------------------------------------

dat_for <- clean_up_data(dat_for)
str(dat_for)

# summarising and converting to longform ----------------------------------

# Summarising over the 40 runs for each of the 12 models to get the mean and standard deviation for each parameter

# Forager dataset
forg <- dat_for %>% 
  group_by(model, food_dens, day) %>% 
  gather("par", "value", c(median.foraging.distance:sd.dance.intensity.for)) %>% 
  group_by(par, model, food_dens, day) %>% 
  summarise(mean = mean(value), var = sd(value))


# Exploratory plots for foragers ----------------------------------------------
forg$par <- as.factor(forg$par)
levels(forg$par)
# Forager variables
g <- ggplot(forg, aes(x=day, y = mean, colour = model, group = model))
g <- g +facet_grid(par~food_dens, scales = "free")
g <- g +geom_ribbon(aes(ymin=mean-var, ymax=mean+var, fill=model), alpha=0.1)
g <- g +geom_line(size=1.5)
g <- g +scale_colour_manual(values=col)
g <- g +scale_fill_manual(values=col)
g

# The specific parameters to highlight are:
# 1. To show that the parameters have been implemented into the model
# mean.dance.intensity.for and sd.dance.intensity.for
# mean.dance.probability.for and sd.dance.probability.for

# 2. To compare the results
# mean.forager.yield
# median.foraging.distance
# mean.search.time.for
# mean.dance.time.for and as.dance.time.for


# Forager dataframe with specific variables -------------------------------
# Input parameters
forg_inp <- forg %>% 
  filter(par == "mean.dance.probability.for" | par == "sd.dance.probability.for" | par == "mean.dance.intensity.for" | par == "sd.dance.intensity.for")
# table(forg_inp$food_dens) # This is 48 days X 4 parameters X 4 models = 768 each
# table(forg_inp$model) # This is 48 days X 3 food density conditions X 4 parameters = 576 each
# The data subsetting is correct

# Output parameters
forg_out <- forg %>% 
  filter(par == "mean.forager.yield" | par == "median.foraging.distance" | par == "mean.search.time.for" | par == "mean.dance.time.for" | par == "sd.dance.time.for")
# table(forg_out$model) # This is 48 days X 3 food density conditions X 5 parameters = 720 each


# Model Input Plots -------------------------------------------------------
# Mean probability
for_pm <- raw_plot(forg_inp, "mean.dance.probability.for", "Mean Dance Probability", 0.4, 0.6)
for_pm

# Variation in probability
for_pv <- raw_plot(forg_inp, "sd.dance.probability.for", "Variation in Dance Probability", 0.1, 0.18)
for_pv

# Mean intensity
for_im <- raw_plot(forg_inp, "mean.dance.intensity.for", "Mean Dance Intensity", 24, 32)
for_im

# Variation in intensity
for_iv <- raw_plot(forg_inp, "sd.dance.intensity.for", "Variation in Dance Intensity", 0, 13)
for_iv


# Multiplot
fi <- plot_grid(for_pm, for_pv, for_im, for_iv,
                nrow=4, ncol=1,
                labels=c("(a)","(b)", "(c)", "(d)"),
                label_size = 12, label_fontface = "plain",
                hjust=0,label_y=c(0.87,1,1,1),
                align="v", axis="l")
fi

save_plot("Analysis_Experiment2_AdaptiveBenefit/Experiment2_RawPlot_InputParameters.pdf", fi, nrow = 4, ncol = 1, base_height = 2.5, base_width = 15)
save_plot("Analysis_Experiment2_AdaptiveBenefit/Experiment2_RawPlot_InputParameters.png", fi, nrow = 4, ncol = 1, base_height = 2.5, base_width = 15)
save_plot("Analysis_Experiment2_AdaptiveBenefit/Experiment2_RawPlot_InputParameters.svg", fi, nrow = 4, ncol = 1, base_height = 2.5, base_width = 15)


# Model output plots ------------------------------------------------------
# Mean Forager Yield
for_ym <- raw_plot(forg_out, "mean.forager.yield", "Mean Yield Forager", 200, 325)
for_ym

# Median Foraging distance
for_fdm <- raw_plot(forg_out, "median.foraging.distance", "Median Foraging Distance", 0, 2.4)
for_fdm

# Mean Search Time
for_sm <- raw_plot(forg_out, "mean.search.time.for", "Mean Search Time", 100, 550)
for_sm

# Mean Dance time
for_dm <- raw_plot(forg_out, "mean.dance.time.for", "Mean Dance Time", 60, 120)
for_dm

# Variation in Dance time
for_dv <- raw_plot(forg_out, "sd.dance.time.for", "Variation in Dance Time", 20, 60)
for_dv


# Multiplot
fo <- plot_grid(for_ym, for_fdm, for_sm, for_dm, for_dv,
                nrow=5, ncol=1,
                labels=c("(a)","(b)", "(c)", "(d)", "(e)"),
                label_size = 12, label_fontface = "plain",
                hjust=0,label_y=c(0.87,1,1,1,1),
                align="v", axis="l")
fo
save_plot("Analysis_Experiment2_AdaptiveBenefit/Experiment2_RawPlot_OutputParameters.pdf", fo, nrow = 5, ncol = 1, base_height = 2, base_width = 15)
save_plot("Analysis_Experiment2_AdaptiveBenefit/Experiment2_RawPlot_OutputParameters.png", fo, nrow = 5, ncol = 1, base_height = 2, base_width = 15)
save_plot("Analysis_Experiment2_AdaptiveBenefit/Experiment2_RawPlot_OutputParameters.svg", fo, nrow = 5, ncol = 1, base_height = 2, base_width = 15)
