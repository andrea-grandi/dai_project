library(msm)
library(truncnorm)
library(tidyr)
library(ggplot2)
library(cowplot)

# Getting Individual Probability Curves -----------------------------------


# Probability Equation ----------------------------------------------------------------

pd <- function(x,t){
  0.956937/(1+exp((t-log(x))/0.26240142))
}


# Getting normal distribution ---------------------------------------------
m <- NULL
m <- sort(rtnorm(300,mean=0.255,sd=0.1,lower=0.01,upper=Inf))
hist(m)


# Getting values of patch quality -----------------------------------------
n <- seq(0,3.5,0.1)
length(n)



# Getting values for 300 individuals --------------------------------------
prob <- matrix(nrow = 36, ncol = 301)
r <- 1
c <- 1


# Looping
for(i in m){
  r <- 1
  for(j in n){
    prob[r,c] <- pd(j,i)
    r <- r+1
  }
  c <- c+1
}


# Getting Prob values for Model 1 agents ----------------------------------
pdold <- (pd(n,0.2721966))
prob[,301] <- pdold


# Converting into dataframe to plot ---------------------------------------

prob <- as.data.frame(prob)
colnames(prob) <- seq(1:301)
prob$patch <- n

pr <- gather(prob, id, prob, 1:301)
str(pr)
pr$id <- as.numeric(pr$id)
pr$mod <- ifelse(pr$id>300,"v0","v1")
table(pr$mod)


# Plotting Probability curves ---------------------------------------------

g.p <- ggplot(pr, aes(x = patch, y = prob, group=id, colour=mod))
g.p <- g.p +geom_line(aes(size=mod,alpha=mod), show.legend = F)
g.p <- g.p +scale_alpha_manual(values=c(0.7,0.2))
g.p <- g.p +scale_size_manual(values=c(0.6,0.3))
g.p <- g.p +scale_colour_manual(values=c("#795548","#7CB342"))
g.p <- g.p +scale_y_continuous(name="Probability of Dancing",limits=c(0,1.1), expand=c(0,0))
g.p <- g.p +scale_x_continuous(name="Food Quality",breaks=c(0,0.5,1,1.5,2,2.5,3,3.5), limits=c(0,3.5), expand=c(0,0.05))
g.p <- g.p +theme_bw()
g.p <- g.p +labs(title = "Individual Probability Curves")
g.p <- g.p +theme(axis.text = element_text(size=10, colour="black"), 
                  axis.title = element_text(size=12, colour="black"),
                  plot.title = element_text(size=14, colour="black", hjust = 0.5))
g.p <- g.p +theme(panel.grid = element_blank(), panel.background = element_blank())
g.p


# Curves for sensitivity analysis ------------------------------------------------

# Defining new function with s variable that changes the CV
pd.sa <- function(x,t,s){
  0.956937/(1+exp((s*t-log(x))/0.26240142))
}

# Getting variable to change values of s
sa <- seq(0.25,2,0.25)

# Getting 300 values from a normal dist
m <- sort(rtnorm(300,mean=0.255,sd=0.1,lower=0.01,upper=Inf))

sa.prob <- as.data.frame(matrix(nrow = 86400, ncol = 4))
colnames(sa.prob) <- c("patch","id","prob","cv")

cov <- c(0.0195,0.0484,0.0877,0.1260,0.1726,0.2371,0.3093,0.3909)


# Looping to get probability values for 8(cv)*36(patch)*300(agents) ---------

r <- 1 #This is used to track the correct row number

for(i in 1:8){ #First loop over the 8 values of cv
  c <- 1 #this reinitialises the numbering for each agent
  for(j in m){ #Loop over these 300 values/300 agents
    for(k in n){ #Loop over patch quality for each agent
      sa.prob[r,1] <- k #Value of patch quality
      sa.prob[r,2] <- c
      sa.prob[r,3] <- pd.sa(k,j,sa[i])
      sa.prob[r,4] <- cov[i]
      r <- r+1 #This value increases by 1 till end of all loops. Used to get row number to fill in data
      print(r)
    }
    c <- c+1 #Agent numbering is increased by 1, till 300
  }
}


sa.prob$lab.cv <- paste("CV =",sa.prob$cv)
sa.prob$lab.cv <- as.factor(sa.prob$lab.cv)
str(sa.prob)



# Plotting this -----------------------------------------------------------

g.psa <- ggplot(sa.prob, aes(x = patch, y = prob, group=id))
g.psa <- g.psa +geom_line(alpha=0.1, size=0.1, colour="#7CB342")
g.psa <- g.psa +facet_wrap(~lab.cv, scales = "free")
g.psa <- g.psa +scale_y_continuous(name="Probability of Dancing",limits=c(0,1.1), expand=c(0,0), breaks=c(0,0.5,1))
g.psa <- g.psa +scale_x_continuous(name="Food Quality",breaks=c(0,1,2,3), limits=c(0,3.5), expand=c(0,0.05))
g.psa <- g.psa +theme_bw()
g.psa <- g.psa +labs(title = "Sensitivity Analysis Curves")
g.psa <- g.psa +theme(axis.text = element_text(size=6, colour="black"), 
                    axis.title = element_text(size=8, colour="black"),
                    axis.title.y = element_blank(),
                    plot.title = element_text(size=14, colour="black", hjust = 0.5))
g.psa <- g.psa +theme(panel.grid = element_blank(), panel.background = element_blank())
g.psa <- g.psa +theme(strip.background = element_blank(), strip.text = element_text(size=8, colour="black", face="bold"))
g.psa


# Combining Plots ---------------------------------------------------------

pl.prob <- plot_grid(g.p,g.psa,nrow=1, ncol=2,labels=c("a","b"),label_size = 12)
pl.prob
save_plot("Model_Input/IndividualProbabilityModulators.pdf",pl.prob, nrow=1, ncol=2, base_width = 3.5, base_height = 5)
save_plot("Model_Input/IndividualProbabilityModulators.png",pl.prob, nrow=1, ncol=2, base_width = 3.5, base_height = 5)
