library(msm)
library(truncnorm)
library(tidyr)
library(ggplot2)
library(cowplot)


# Getting Individual Intensity curves -------------------------------------

# Intensity equation ------------------------------------------------------

intd <- function(x,t){
  57*x*t
}


# Getting values of modulator from a normal distribution ------------------
o <- sort(rtnorm(300,mean=0.255,sd=0.1,lower=0.01,upper=Inf))
hist(o)

l <- NULL
l <- (o * 1) + 0

# Getting values of patch quality -----------------------------------------
n <- seq(0,3.5,0.1)
length(n)


# Getting values for 300 individuals --------------------------------------
int <- matrix(nrow = 36, ncol = 301)
r <- 1
c <- 1


# Looping
for(i in l){
  r <- 1
  for(j in n){
    int[r,c] <- intd(j,i)
    r <- r+1
  }
  c <- c+1
}


# Getting Int values for Model 1 agents ----------------------------------
intold <- (intd(n,0.2721966))
int[,301] <- intold


# Converting into dataframe to plot ---------------------------------------

int <- as.data.frame(int)
colnames(int) <- seq(1:301)
int$patch <- n

in2 <- gather(int, id, int, 1:301)
str(in2)
in2$id <- as.numeric(in2$id)
in2$mod <- ifelse(in2$id>300,"v0","v1")
table(in2$mod)

# Plotting Intensity curves ---------------------------------------------

g.i <- ggplot(in2, aes(x = patch, y = int, group=id, colour=mod))
g.i <- g.i +geom_line(aes(size=mod,alpha=mod), show.legend = F)
g.i <- g.i +scale_alpha_manual(values=c(0.7,0.2))
g.i <- g.i +scale_size_manual(values=c(0.6,0.3))
g.i <- g.i +scale_colour_manual(values=c("#795548","#039BE5"))
g.i <- g.i +scale_y_continuous(name="Intensity of Dances",limits=c(0,120), expand=c(0,0))
g.i <- g.i +scale_x_continuous(name="Food Quality",breaks=c(0,0.5,1,1.5,2,2.5,3,3.5), limits=c(0,3.5), expand=c(0,0.05))
g.i <- g.i +theme_bw()
g.i <- g.i +labs(title = "Individual Intensity Curves")
g.i <- g.i +theme(axis.text = element_text(size=10, colour="black"), 
                  axis.title = element_text(size=12, colour="black"),
                  plot.title = element_text(size=14, colour="black", hjust = 0.5))
g.i <- g.i +theme(panel.grid = element_blank(), panel.background = element_blank())
g.i



# Curves for sensitivity analysis ------------------------------------------------

cv.i <- seq(0.1,0.9,0.1)
mean.i <- c(0.2295,0.204,0.1785,0.153,0.1275,0.102,0.0765,0.051,0.0225)

sa.int <- as.data.frame(matrix(nrow = 97200, ncol = 4))
colnames(sa.int) <- c("patch","id","int","cv")

cov <- c(0.0394,0.0733,0.1119,0.1485,0.1930,0.2213,0.2750,0.3078,0.3346)

# Looping to get intensity values for 9(cv)*36(patch)*300(agents) ---------

r <- 1 #This is used to track the correct row number

for(i in 1:9){ #First loop over the 9 values of cv
  l <- (o * cv.i[i]) + mean.i[i] #Getting 300 values from a normal distribution with this cv
  c <- 1 #this reinitialises the numbering for each agent
  for(j in l){ #Loop over these 300 values/300 agents
    for(k in n){ #Loop over patch quality for each agent
      sa.int[r,1] <- k #Value of patch quality
      sa.int[r,2] <- c
      sa.int[r,3] <- intd(k,j)
      sa.int[r,4] <- cov[i]
      r <- r+1 #This value increases by 1 till end of all loops. Used to get row number to fill in data
      print(r)
    }
    c <- c+1 #Agent numbering is increased by 1, till 300
  }
}

sa.int$lab.cv <- paste("CV =",sa.int$cv)
sa.int$lab.cv <- as.factor(sa.int$lab.cv)
str(sa.int)


# Plotting this -----------------------------------------------------------

g.isa <- ggplot(sa.int, aes(x = patch, y = int, group=id))
g.isa <- g.isa + geom_line(alpha=0.1, size=0.1, colour="#039BE5")
g.isa <- g.isa + facet_wrap(~lab.cv, scales = "free")
g.isa <- g.isa +scale_y_continuous(name="Intensity of Dances",limits=c(0,120), expand=c(0,0), breaks=c(0,50,100))
g.isa <- g.isa +scale_x_continuous(name="Food Quality",breaks=c(0,1,2,3), limits=c(0,3.5), expand=c(0,0.05))
g.isa <- g.isa +theme_bw()
g.isa <- g.isa +labs(title = "Sensitivity Analysis Curves")
g.isa <- g.isa +theme(axis.text = element_text(size=6, colour="black"), 
                  axis.title = element_text(size=8, colour="black"),
                  axis.title.y = element_blank(),
                  plot.title = element_text(size=14, colour="black", hjust = 0.5))
g.isa <- g.isa +theme(panel.grid = element_blank(), panel.background = element_blank())
g.isa <- g.isa +theme(strip.background = element_blank(), strip.text = element_text(size=8, colour="black", face="bold"))
g.isa



# Combining Plots ---------------------------------------------------------

pl.int <- plot_grid(g.i,g.isa,nrow=1, ncol=2,labels=c("a","b"),label_size = 12)
pl.int
save_plot("Model_Input/IndividualIntensityModulators.pdf",pl.int, nrow=1, ncol=2, base_width = 3.5, base_height = 5)
save_plot("Model_Input/IndividualIntensityModulators.png",pl.int, nrow=1, ncol=2, base_width = 3.5, base_height = 5)
