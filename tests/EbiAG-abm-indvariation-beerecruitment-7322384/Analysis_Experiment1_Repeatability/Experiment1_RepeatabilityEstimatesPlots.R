library(ggplot2)
library(ggthemes)
library(cowplot)

# Load dataframe ----------------------------------------------------------

d <- read.csv("Analysis_Experiment1_Repeatability/RepeatabilityEstimates_4Models_100Runs.csv")

col <- c("#795548","#7CB342","#039BE5","#00897B")
g1 <- ggplot(d, aes(x=model, y=rep_estimate, colour=model, fill=model)) +
  geom_violin(trim=FALSE, alpha=0.5) +  
  geom_boxplot(color="black",width=0.05, outlier.alpha = 0)
g1 <- g1 +scale_fill_manual(values=col)
g1 <- g1 +scale_color_manual(values=col)
g1 <- g1 +theme_bw()
g1 <- g1 +theme(axis.ticks.x = element_blank(), 
                axis.text.y = element_text(size=10, colour="black"), axis.title.y = element_text(size=12, colour="black"),
                axis.text.x = element_text(size=12, colour="black"), axis.title.x = element_blank())
g1 <- g1 +theme(panel.grid = element_blank(), panel.background = element_blank())
g1 <- g1 +theme(axis.line.x = element_blank())
g1 <- g1 +scale_x_discrete(name="", labels=c("Model1" = "Model 1","Model2" = "Model 2","Model3" = "Model 3","Model4" = "Model 4"))
g1 <- g1 +scale_y_continuous(name="Repeatability Estimate", limits = c(-0.03,1))
g1 <- g1 +theme(legend.position = "none")
g1 <- g1 +annotate("text",label="a",x=1,y=0.85, size=4)
g1 <- g1 +annotate("text",label="b",x=2,y=0.85, size=4)
g1 <- g1 +annotate("text",label="c",x=3,y=0.85, size=4)
g1 <- g1 +annotate("text",label="d",x=4,y=0.85, size=4)
g1

save_plot("Analysis_Experiment1_Repeatability/RepeatabilityEstimates_AllModels.pdf",g1, nrow=1, ncol=1, base_width = 7.5, base_height = 5)
save_plot("Analysis_Experiment1_Repeatability/RepeatabilityEstimates_AllModels.png",g1, nrow=1, ncol=1, base_width = 7.5, base_height = 5)
save_plot("Analysis_Experiment1_Repeatability/RepeatabilityEstimates_AllModels.svg",g1, nrow=1, ncol=1, base_width = 7.5, base_height = 5)

# Comparing empirical values with model values -----------------------------------------

# Summary dataframe --------------------------------------------------------------------
d_sum <- d %>% 
  group_by(model) %>% 
  summarise(mean = mean(rep_estimate), lwr = (mean(rep_estimate) - (1.96*sd(rep_estimate))), 
            upr = (mean(rep_estimate) + (1.96*sd(rep_estimate))))  
d_sum[,1] <- c("Model 1", "Model 2", "Model 3", "Model 4")

# Adding values from experiments and keeping only values for model 3 and 4
d_sum[5,] <- list("Empirical\nObservations", 0.5263, 0.4295, 0.6002)
d_sum <- d_sum %>% 
  arrange(model) %>% 
  slice(-c(2,3))


# Plot for comparing empirtical and model values --------------------------
col2 <- c("#FF0000","#039BE5","#00897B")
g2 <- ggplot(d_sum, aes(x=model, y=mean, colour=model))
g2 <- g2 +geom_rect(aes(xmin=-Inf, xmax=Inf,ymin=lwr[1], ymax=upr[1]), fill="#9E9E9E", alpha=0.1, linetype=0)
g2 <- g2 +geom_hline(yintercept = d_sum$mean[1], linetype=2)
g2 <- g2 +geom_point(size=3)
g2 <- g2 +geom_errorbar(aes(ymin=lwr, ymax=upr, colour=model), width=0, size=1.2)
g2 <- g2 +theme_bw()
g2 <- g2 +scale_colour_manual(values=col2)
g2 <- g2 +theme(axis.ticks.x = element_blank(), 
                axis.text.y = element_text(size=10, colour="black"), axis.title.y = element_blank(),
                axis.text.x = element_text(size=12, colour="black"), axis.title.x = element_blank())
g2 <- g2 +theme(panel.grid = element_blank(), panel.background = element_blank())
g2 <- g2 +theme(axis.line.x = element_blank())
g2 <- g2 +scale_y_continuous(name="Repeatability Estimate", limits = c(-0.03,1))
g2 <- g2 +theme(legend.position = "none")
g2


save_plot("Analysis_Experiment1_Repeatability/RepeatabilityEstimates_EmpiricalComparison.pdf", g2, nrow = 1, ncol = 1, base_height = 5, base_width = 5)
save_plot("Analysis_Experiment1_Repeatability/RepeatabilityEstimates_EmpiricalComparison.png", g2, nrow = 1, ncol = 1, base_height = 5, base_width = 5)
save_plot("Analysis_Experiment1_Repeatability/RepeatabilityEstimates_EmpiricalComparison.svg", g2, nrow = 1, ncol = 1, base_height = 5, base_width = 5)
