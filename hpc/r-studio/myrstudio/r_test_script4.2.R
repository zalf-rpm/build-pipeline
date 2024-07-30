# Purpose: R script to test RScript on HPC on a RStudio playground
# it requires that the playground has been started at least once before
# with the RStudio image
# Other requirements:
# this.path as a user library
# mounted /myhome, /project, /data
# optional: some command line arguments
# optional: /scratch, /beegfs/common/singularity, /beegfs/common/batch


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

# list files in mounted directories
# home directory
print("Home directory:")
print(list.files("/myhome"))
# project directory
print("Project directory:")
print(list.files("/project"))
# data directory
print("Data directory:")
print(list.files("/data"))
# if mounted
if (file.exists("/scratch")) {
    # scratch directory
    print("Scratch directory:")
    print(list.files("/scratch"))
}
if (file.exists("/beegfs/common/singularity")) {
    # beegfs directory
    print("Beegfs singularity directory:")
    print(list.files("/beegfs/common/singularity"))
}
if (file.exists("/beegfs/common/batch")) {
    # beegfs directory
    print("Beegfs batch directory:")
    print(list.files("/beegfs/common/batch"))
}