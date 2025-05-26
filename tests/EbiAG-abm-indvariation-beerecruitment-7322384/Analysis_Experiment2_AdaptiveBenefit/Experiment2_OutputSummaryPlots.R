library(ggplot2)
library(cowplot)
source("Analysis_Experiment2_AdaptiveBenefit/Experiment2_Functions.R")

# Load Dataframes ----------------------------------------------------------

margm <- read.csv("Analysis_Experiment2_AdaptiveBenefit/Experiment2_OutputSummary_MarginalMeans.csv")
str(margm)

# Releveling Food density
margm$food_dens <- factor(margm$food_dens, level=c("Low", "Medium", "High"))
levels(margm$food_dens)


# Results 1 - median Foraging Distance ------------------------------------
res_fdm <- data.frame(
  label=margm[which(margm$Par=="Median Foraging Distance"),"Diff_Labels"],
  model=rep(c("Model1", "Model2", "Model3", "Model4"), by=3),
  x=rep(c("Low", "Medium", "High"), each=4),
  y=c(1.34, 1.34, 1.34, 1.34, 0.85, 0.85, 0.85, 0.85, 0.7, 0.7, 0.7, 0.7)
)

# Plot 1 - Median Foraging distance ---------------------------------------
min(margm[which(margm$Par=="Median Foraging Distance"),7])
max(margm[which(margm$Par=="Median Foraging Distance"),8])
fo_mm_fdm <- margmean_plot(margm,"Median Foraging Distance", "Median Foraging Distance (km)", 0.5, 1.4, res_fdm)
fo_mm_fdm


# Results 2 - yield per forager ------------------------------------
res_ym <- data.frame(
  label=margm[which(margm$Par=="Mean Forager Yield"),"Diff_Labels"],
  model=rep(c("Model1", "Model2", "Model3", "Model4"), by=3),
  x=rep(c("Low", "Medium", "High"), each=4),
  y=c(269, 269, 269, 269, 280, 280, 280, 280, 283, 283, 283, 283)
)


# Plot 2 - Mean Yield per Forager -----------------------------------------
min(margm[which(margm$Par=="Mean Forager Yield"),7])
max(margm[which(margm$Par=="Mean Forager Yield"),8])
fo_mm_ym <- margmean_plot(margm, "Mean Forager Yield","Mean Yield per Forager (Joules)", 260, 285, res_ym)
fo_mm_ym


# Results 3 - Mean Search Time --------------------------------------------
res_sm <- data.frame(
  label=margm[which(margm$Par=="Mean Search Time"),"Diff_Labels"],
  model=rep(c("Model1", "Model2", "Model3", "Model4"), by=3),
  x=rep(c("Low", "Medium", "High"), each=4),
  y=c(379, 379, 379, 379, 270, 270, 270, 270, 220, 220, 220, 220)
)


# Plot 3 - Mean Search Time -----------------------------------------------
min(margm[which(margm$Par=="Mean Search Time"),7])
max(margm[which(margm$Par=="Mean Search Time"),8])
fo_mm_sm <- margmean_plot(margm, "Mean Search Time", "Mean Search Time (s)", 180, 380, res_sm)
fo_mm_sm


# Results 4 - Mean Dance Time --------------------------------------------
res_dm <- data.frame(
  label=margm[which(margm$Par=="Mean Dance Activity"),"Diff_Labels"],
  model=rep(c("Model1", "Model2", "Model3", "Model4"), by=3),
  x=rep(c("Low", "Medium", "High"), each=4),
  y=c(100.5, 100.5, 100.5, 100.5, 106, 106, 106, 106, 108, 108, 108, 108)
)


# Plot 4 - Mean Dance Time -----------------------------------------------
min(margm[which(margm$Par=="Mean Dance Activity"),7])
max(margm[which(margm$Par=="Mean Dance Activity"),8])
fo_mm_dm <- margmean_plot(margm, "Mean Dance Activity", "Mean Dance Time (s)", 95, 110, res_dm)
fo_mm_dm


# Results 5 - Mean Variation in Dance Time --------------------------------------------
res_ds <- data.frame(
  label=margm[which(margm$Par=="Mean Dance Activity Variation"),"Diff_Labels"],
  model=rep(c("Model1", "Model2", "Model3", "Model4"), by=3),
  x=rep(c("Low", "Medium", "High"), each=4),
  y=c(48, 48, 48, 48, 48, 48, 48, 48, 48, 48, 48, 48)
)


# Plot 4 - Mean Variation in Dance Time -----------------------------------------------
min(margm[which(margm$Par=="Mean Dance Activity Variation"),7])
max(margm[which(margm$Par=="Mean Dance Activity Variation"),8])
fo_mm_ds <- margmean_plot(margm, "Mean Dance Activity Variation", "Mean Variation in\nDance Time", 25, 50, res_ds)
fo_mm_ds


# Multiplot 1 ---------------------------------------------------------------
fo_mm_1 <- plot_grid(fo_mm_dm, fo_mm_ym,
                     nrow=1, ncol=2,
                     labels=c("(a)","(b)"),
                     label_size = 12, label_fontface = "plain",
                     hjust=0,
                     align="h", axis="b")
fo_mm_1
save_plot("Analysis_Experiment2_AdaptiveBenefit/Experiment2_OutputComparison_Plot1.png", fo_mm_1, nrow = 1, ncol = 2, base_height = 5, base_width = 7.5)
save_plot("Analysis_Experiment2_AdaptiveBenefit/Experiment2_OutputComparison_Plot1.pdf", fo_mm_1, nrow = 1, ncol = 2, base_height = 5, base_width = 7.5)
save_plot("Analysis_Experiment2_AdaptiveBenefit/Experiment2_OutputComparison_Plot1.svg", fo_mm_1, nrow = 1, ncol = 2, base_height = 5, base_width = 7.5)


# Multiplot 2 ---------------------------------------------------------------
fo_mm_2 <- plot_grid(fo_mm_fdm, fo_mm_sm,
                     nrow=1, ncol=2,
                     labels=c("(a)","(b)"),
                     label_size = 12, label_fontface = "plain",
                     hjust=0,
                     align="h", axis="b")
fo_mm_2
save_plot("Analysis_Experiment2_AdaptiveBenefit/Experiment2_OutputComparison_Plot2.png", fo_mm_2, nrow = 1, ncol = 2, base_height = 5, base_width = 7.5)
save_plot("Analysis_Experiment2_AdaptiveBenefit/Experiment2_OutputComparison_Plot2.pdf", fo_mm_2, nrow = 1, ncol = 2, base_height = 5, base_width = 7.5)
save_plot("Analysis_Experiment2_AdaptiveBenefit/Experiment2_OutputComparison_Plot2.svg", fo_mm_2, nrow = 1, ncol = 2, base_height = 5, base_width = 7.5)
