library(reshape2)
library(stringr)
library(ggplot2)
library(cowplot)


# Loading the dataframe ---------------------------------------------------

dat<- read.csv("Analysis_SensitivityAnalysis_Repeatability/SensitivityAnalysis_RepeatabilityEstimates_Summary.csv")
str(dat)


# Contour Plot for Mean ---------------------------------------------------
# Subsetting only cv of p,i and mean repeatability estimate
dat_mean <- dat[,c(3,5,6)]

# Predicting the values in the middle -------------------------------------
# Making a LOESS model
dat_mean.loess <- loess(mean~prob_cv*int_cv, data = dat_mean)

# Obtaining a range of prob_cv and int_cv values
xgrid <- seq(min(dat_mean$prob_cv), max(dat_mean$prob_cv), 0.005)
ygrid <- seq(min(dat_mean$int_cv), max(dat_mean$int_cv), 0.005)

# Obtaining all combinations
data.fit <-  expand.grid(prob_cv = xgrid, int_cv = ygrid)

# Predicting rep value for all combination
mtrx3d_mean <-  predict(dat_mean.loess, newdata = data.fit)


# Obtaining dataframe for ggplot2 -----------------------------------------
mtrx.melt_mean <- melt(mtrx3d_mean, id.vars = c("prob_cv", "int_cv"), measure.vars = "mean")
names(mtrx.melt_mean) <- c("prob_cv", "int_cv","mean")


# Removing the string part to convert to numeric form
mtrx.melt_mean$prob_cv <- as.numeric(str_sub(mtrx.melt_mean$prob_cv, str_locate(mtrx.melt_mean$prob_cv, "=")[1,1] + 1))
mtrx.melt_mean$int_cv <- as.numeric(str_sub(mtrx.melt_mean$int_cv, str_locate(mtrx.melt_mean$int_cv, "=")[1,1] + 1))



# Making Coloured Contour plot --------------------------------------------

g <- ggplot(mtrx.melt_mean, aes(x=prob_cv,y=int_cv,z=mean))
g <- g + stat_contour(geom="polygon", aes(fill = ..level..))
g <- g + geom_tile(aes(fill=mean))
g <- g + stat_contour(bins = 15)
g <- g + scale_x_continuous(name="Coefficient of Variation in Probability", expand=c(0,0)) 
g <- g + scale_y_continuous(name="Coefficient of Variation in Intensity", expand=c(0,0))
g <- g + scale_fill_distiller(name="Repeatability\nEstimate",palette= "Spectral", direction=-1)
g <- g + theme_bw()
g <- g + theme(axis.text=element_text(size=10), axis.title = element_text(size=12))
g <- g + theme(axis.line.y = element_line(size=1), axis.line.x = element_blank())
g <- g + theme(strip.background = element_blank(), strip.text = element_text(size=14, colour="black", face="bold"))
g <- g + theme(panel.grid = element_blank(), panel.background = element_blank())
g
save_plot("Analysis_SensitivityAnalysis_Repeatability/SensitivityAnalysis_ContourPlot_MeanRepValues.pdf",g, nrow=1, ncol=1, base_width = 7.5, base_height = 6.7)
save_plot("Analysis_SensitivityAnalysis_Repeatability/SensitivityAnalysis_ContourPlot_MeanRepValues.png",g, nrow=1, ncol=1, base_width = 7.5, base_height = 6.7)
save_plot("Analysis_SensitivityAnalysis_Repeatability/SensitivityAnalysis_ContourPlot_MeanRepValues.svg",g, nrow=1, ncol=1, base_width = 7.5, base_height = 6.7)


# Contour Plot for SD ---------------------------------------------------
# Subsetting only cv of p,i and sd repeatability estimate
dat_sd <- dat[,c(4,5,6)]

# Predicting the values in the middle -------------------------------------
# Making a LOESS model
dat_sd.loess <- loess(sd~prob_cv*int_cv, data = dat_sd)

# Obtaining a range of prob_cv and int_cv values
xgrid <- seq(min(dat_sd$prob_cv), max(dat_sd$prob_cv), 0.005)
ygrid <- seq(min(dat_sd$int_cv), max(dat_sd$int_cv), 0.005)

# Obtaining all combinations
data_sd.fit <-  expand.grid(prob_cv = xgrid, int_cv = ygrid)

# Predicting rep value for all combination
mtrx3d_sd <-  predict(dat_sd.loess, newdata = data_sd.fit)


# Obtaining dat_sdaframe for ggplot2 -----------------------------------------
mtrx.melt_sd <- melt(mtrx3d_sd, id.vars = c("prob_cv", "int_cv"), measure.vars = "sd")
names(mtrx.melt_sd) <- c("prob_cv", "int_cv","sd")


# Removing the string part to convert to numeric form
mtrx.melt_sd$prob_cv <- as.numeric(str_sub(mtrx.melt_sd$prob_cv, str_locate(mtrx.melt_sd$prob_cv, "=")[1,1] + 1))
mtrx.melt_sd$int_cv <- as.numeric(str_sub(mtrx.melt_sd$int_cv, str_locate(mtrx.melt_sd$int_cv, "=")[1,1] + 1))



# Making Coloured Contour plot --------------------------------------------

g <- ggplot(mtrx.melt_sd, aes(x=prob_cv,y=int_cv,z=sd))
g <- g + stat_contour(geom="polygon", aes(fill = ..level..))
g <- g + geom_tile(aes(fill=sd))
g <- g + stat_contour(bins = 15)
g <- g + scale_x_continuous(name="Coefficient of Variation in Probability", expand=c(0,0)) 
g <- g + scale_y_continuous(name="Coefficient of Variation in Intensity", expand=c(0,0))
g <- g + scale_fill_distiller(name="Variation in\nRepeatability\nEstimate",palette= "Spectral", direction=-1)
g <- g + theme_bw()
g <- g + theme(axis.text=element_text(size=10), axis.title = element_text(size=12))
g <- g + theme(axis.line.y = element_line(size=1), axis.line.x = element_blank())
g <- g + theme(strip.background = element_blank(), strip.text = element_text(size=14, colour="black", face="bold"))
g <- g + theme(panel.grid = element_blank(), panel.background = element_blank())
g
save_plot("Analysis_SensitivityAnalysis_Repeatability/SensitivityAnalysis_ContourPlot_SDRepValues.pdf",g, nrow=1, ncol=1, base_width = 7.5, base_height = 6.7)
save_plot("Analysis_SensitivityAnalysis_Repeatability/SensitivityAnalysis_ContourPlot_SDRepValues.png",g, nrow=1, ncol=1, base_width = 7.5, base_height = 6.7)
save_plot("Analysis_SensitivityAnalysis_Repeatability/SensitivityAnalysis_ContourPlot_SDRepValues.svg",g, nrow=1, ncol=1, base_width = 7.5, base_height = 6.7)
