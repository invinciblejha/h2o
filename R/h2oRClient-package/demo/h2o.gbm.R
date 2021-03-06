# This is a demo of H2O's GBM function
# It imports a data set, parses it, and prints a summary
# Then, it runs GBM on a subset of the dataset
# Note: This demo runs H2O on localhost:54321
library(h2o)
h2o.installDepPkgs()
localH2O = h2o.init(ip = "localhost", port = 54321, startH2O = TRUE, silentUpgrade = TRUE, promptUpgrade = FALSE)

prostate.hex = h2o.importFile(localH2O, system.file("extdata", "prostate.csv", package="h2oRClient"), "prostate.hex")
summary(prostate.hex)
prostate.gbm = h2o.gbm(x = setdiff(colnames(prostate.hex), "CAPSULE"), y = "CAPSULE", data = prostate.hex, n.trees = 10, interaction.depth = 5, shrinkage = 0.1)
print(prostate.gbm)
prostate.gbm2 = h2o.gbm(x = c("AGE", "RACE", "PSA", "VOL", "GLEASON"), y = "CAPSULE", data = prostate.hex, n.trees = 10, interaction.depth = 8, n.minobsinnode = 10, shrinkage = 0.2)
print(prostate.gbm2)

# This is a demo of H2O's GBM use of default parameters on iris dataset (three classes)
iris.hex = h2o.importFile(localH2O, system.file("extdata", "iris.csv", package="h2oRClient"), "iris.hex")
summary(iris.hex)
iris.gbm = h2o.gbm(x = 1:4, y = 5, data = iris.hex)
print(iris.gbm)
