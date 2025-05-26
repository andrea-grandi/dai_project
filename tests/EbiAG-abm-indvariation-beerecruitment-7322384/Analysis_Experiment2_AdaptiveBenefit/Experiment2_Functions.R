library(dplyr)
library(ggplot2)
library(cowplot)


# Colour code for the models ----------------------------------------------

col <- c("#795548","#7CB342","#039BE5","#00897B")


# Specific Parameter plots for foragers -----------------------------------
fooddens_names <- c("Low Food Density", "Medium Food Density", "High Food Density")
names(fooddens_names) <- c("Low", "Medium", "High")


# Function to add Model names and Foode Density Labels --------------------

clean_up_data <- function(dat) {
  dat$model <- if_else(dat$probability.modulator.on=="True", 
                       if_else(dat$intensity.modulator.on=="True", "Model_4", "Model_2"),
                       if_else(dat$intensity.modulator.on=="True", "Model_3", "Model_1"))
  dat$food_dens <- if_else(dat$density.food==0.01, "Low", if_else(dat$density.food==0.05, "Medium", "High"))
  dat$food_dens <- factor(dat$food_dens, level=c("Low", "Medium", "High"))
  dat$model <- as.factor(dat$model)
  return(dat)
}

# Function to create raw data plots ---------------------------------------

raw_plot <- function(dat, par_name, lbl_name, ylim_lwr, ylim_upr) {
  g <- ggplot(dat[which(dat$par==par_name),], aes(x=day, y = mean, colour = model, group = model))
  g <- g +facet_grid(.~food_dens, scales = "fixed", labeller = labeller(food_dens=fooddens_names))
  g <- g +geom_ribbon(aes(ymin=mean-var, ymax=mean+var, fill=model), alpha=0.1, size=0.1)
  g <- g +geom_line(size=1)
  g <- g +scale_colour_manual(values=col)
  g <- g +scale_fill_manual(values=col)
  g <- g +scale_y_continuous(name = lbl_name, limits = c(ylim_lwr, ylim_upr))
  g <- g +scale_x_continuous(name = "Day")
  g <- g +theme_bw()
  g <- g +theme(axis.text = element_text(colour="black"), axis.title = element_text(colour="black", size=10))
  g <- g +theme(panel.grid = element_blank(), panel.background = element_blank())
  g <- g +theme(strip.background = element_blank(), strip.text = element_text(size=12, face="bold", colour="black"))
  g <- g +theme(legend.position = "none")
  return(g)
}

# Function to create marginal mean comparison plots -----------------------

margmean_plot <- function(dat, par_name, lbl_name, ylim_lwr, ylim_upr, res_txt) {
  g <- ggplot(dat[which(dat$Par==par_name),], aes(x=food_dens, y = emmean, colour = model, group = model))
  g <- g +geom_point(position = position_dodge(width=0.45), size=2) # Change size to 4 for multiplot 1 and 2 for multiplot 2
  g <- g +geom_errorbar(aes(ymin=lower.CL, ymax=upper.CL), position = position_dodge(width=0.45), size=1, width=0)
  g <- g +scale_colour_manual(values=col)
  g <- g +scale_y_continuous(name = lbl_name, limits = c(ylim_lwr, ylim_upr))
  g <- g +scale_x_discrete(name = "Environmental Food Density")
  g <- g +theme_bw()
  g <- g +theme(axis.text = element_text(colour="black"), axis.title = element_text(colour="black"))
  g <- g +theme(panel.grid = element_blank(), panel.background = element_blank())
  g <- g +theme(legend.position = "none")
  g <- g +geom_text(data=res_txt, mapping = aes(label=label,x=x,y=y,group=model), 
                    position = position_dodge(width=0.45), size=3, colour="black")
  return(g)
}
