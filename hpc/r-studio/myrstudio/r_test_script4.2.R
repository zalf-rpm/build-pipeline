# load a system library
library(ggplot2)

# print path to user libraries
libpath <- .libPaths()
print(libpath)

# load a user library
library(this.path)

# print current working directory
current_dir <- getwd()
print(current_dir)

# read command line arguments
args <- commandArgs(trailingOnly = TRUE)

# print command line arguments
print(args)

# create a data frame
data <- data.frame(
    name = c("A", "B", "C", "D"),
    value = c(3, 12, 5, 18)
)

# create a bar plot
p <- ggplot(data, aes(x = name, y = value)) +
    geom_bar(stat = "identity")

# save the plot
ggsave("plot4.2.png", plot = p, device = "png")

