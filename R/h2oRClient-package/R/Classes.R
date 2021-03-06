MAX_INSPECT_VIEW = 10000

# Class definitions
# WARNING: Do NOT touch the env slot! It is used to link garbage collection between R and H2O
# setClass("H2OClient", representation(ip="character", port="numeric"), prototype(ip="127.0.0.1", port=54321))
setClass("H2OClient", representation(ip="character", port="numeric"), prototype(ip="127.0.0.1", port=54321))
setClass("H2ORawData", representation(h2o="H2OClient", key="character", env="environment"))
# setClass("H2OParsedData", representation(h2o="H2OClient", key="character"))
setClass("H2OParsedData", representation(h2o="H2OClient", key="character", env="environment"))
setClass("H2OLogicalData", contains="H2OParsedData")
setClass("H2OModel", representation(key="character", data="H2OParsedData", model="list", env="environment", "VIRTUAL"))
setClass("H2OGrid", representation(key="character", data="H2OParsedData", model="list", sumtable="list", "VIRTUAL"))

setClass("H2OGLMModel", contains="H2OModel", representation(xval="list"))
setClass("H2OGLMGrid", contains="H2OGrid")
setClass("H2OKMeansModel", contains="H2OModel")
setClass("H2ONNModel", contains="H2OModel")
setClass("H2ORForestModel", contains="H2OModel")
setClass("H2OPCAModel", contains="H2OModel")
setClass("H2OGBMModel", contains="H2OModel")
setClass("H2OGBMGrid", contains="H2OGrid")

setClass("H2ORawData2", representation(h2o="H2OClient", key="character"))
setClass("H2OParsedData2", representation(h2o="H2OClient", key="character"))
setClass("H2OLogicalData2", contains="H2OParsedData2")

# Register finalizers for H2O data and model objects
# setMethod("initialize", "H2ORawData", function(.Object, h2o = new("H2OClient"), key = "") {
#   .Object@h2o = h2o
#   .Object@key = key
#   .Object@env = new.env()
#   
#   assign("h2o", .Object@h2o, envir = .Object@env)
#   assign("key", .Object@key, envir = .Object@env)
#   
#   # Empty keys don't refer to any object in H2O
#   if(key != "") reg.finalizer(.Object@env, h2o.__finalizer)
#   return(.Object)
# })
# 
# setMethod("initialize", "H2OParsedData", function(.Object, h2o = new("H2OClient"), key = "") {
#   .Object@h2o = h2o
#   .Object@key = key
#   .Object@env = new.env()
#   
#   assign("h2o", .Object@h2o, envir = .Object@env)
#   assign("key", .Object@key, envir = .Object@env)
#   
#   # Empty keys don't refer to any object in H2O
#   if(key != "") reg.finalizer(.Object@env, h2o.__finalizer)
#   return(.Object)
# })
# 
# setMethod("initialize", "H2OModel", function(.Object, key = "", data = new("H2OParsedData"), model = list()) {
#   .Object@key = key
#   .Object@data = data
#   .Object@model = model
#   .Object@env = new.env()
#   
#   assign("h2o", .Object@data@h2o, envir = .Object@env)
#   assign("key", .Object@key, envir = .Object@env)
#   
#   # Empty keys don't refer to any object in H2O
#   if(key != "") reg.finalizer(.Object@env, h2o.__finalizer)
#   return(.Object)
# })

# Class display functions
setMethod("show", "H2OClient", function(object) {
  cat("IP Address:", object@ip, "\n")
  cat("Port      :", object@port, "\n")
})

setMethod("show", "H2ORawData", function(object) {
  print(object@h2o)
  cat("Raw Data Key:", object@key, "\n")
})

setMethod("show", "H2OParsedData", function(object) {
  print(object@h2o)
  cat("Parsed Data Key:", object@key, "\n")
})

setMethod("show", "H2OGLMModel", function(object) {
  print(object@data)
  cat("GLM Model Key:", object@key, "\n\nCoefficients:\n")
  
  model = object@model
  print(round(model$coefficients,5))
  cat("\nDegrees of Freedom:", model$df.null, "Total (i.e. Null); ", model$df.residual, "Residual\n")
  cat("Null Deviance:    ", round(model$null.deviance,1), "\n")
  cat("Residual Deviance:", round(model$deviance,1), " AIC:", ifelse( is.numeric(model$aic), round(model$aic,1), 'NaN'), "\n")
  cat("Avg Training Error Rate:", round(model$train.err,5), "\n")
  
  # if(model$family == "binomial") {
  if(model$family$family == "binomial") {
    cat("AUC:", ifelse(is.numeric(model$auc), round(model$auc,5), 'NaN'), " Best Threshold:", round(model$threshold,5), "\n")
    cat("\nConfusion Matrix:\n"); print(model$confusion)
  }
    
  if(length(object@xval) > 0) {
    cat("\nCross-Validation Models:\n")
    # if(model$family == "binomial") {
    if(model$family$family == "binomial") {
      modelXval = t(sapply(object@xval, function(x) { c(x@model$threshold, x@model$auc, x@model$class.err) }))
      colnames(modelXval) = c("Best Threshold", "AUC", "Err(0)", "Err(1)")
    } else {
      modelXval = sapply(object@xval, function(x) { x@model$train.err })
      modelXval = data.frame(modelXval)
      colnames(modelXval) = c("Error")
    }
    rownames(modelXval) = paste("Model", 0:(nrow(modelXval)-1))
    print(modelXval)
  }
})

setMethod("show", "H2OGLMGrid", function(object) {
  print(object@data)
  cat("GLMGrid Model Key:", object@key, "\n")
  
  temp = data.frame(t(sapply(object@sumtable, c)))
  cat("\nSummary\n"); print(temp)
})

setMethod("show", "H2OKMeansModel", function(object) {
  print(object@data)
  cat("K-Means Model Key:", object@key)
  
  model = object@model
  cat("\n\nK-means clustering with", length(model$size), "clusters of sizes "); cat(model$size, sep=", ")
  cat("\n\nCluster means:\n"); print(model$centers)
  cat("\nClustering vector:\n"); print(model$cluster)  # summary(model$cluster) currently broken
  cat("\nWithin cluster sum of squares by cluster:\n"); print(model$withinss)
  cat("\nAvailable components:\n\n"); print(names(model))
})


setMethod("show", "H2ONNModel", function(object) {
  print(object@data)
  cat("NN Model Key:", object@key)
  
  model = object@model
  cat("\n\nTraining classification error:\n"); print(model$train_class_error)
  cat("\nTraining square error:\n"); print(model$train_sqr_error)
  cat("\n\nValidation classification error:\n"); print(model$valid_class_error)
  cat("\nValidation square error:\n"); print(model$valid_sqr_error)
  cat("\n\nConfusion matrix:\n"); print(model$confusion)
 
})

setMethod("show", "H2ORForestModel", function(object) {
  print(object@data)
  cat("Random Forest Model Key:", object@key)
  
  model = object@model
  cat("\n\nType of random forest:", model$type)
  cat("\nNumber of trees:", model$ntree)
  cat("\n\nOOB estimate of error rate: ", round(100*model$oob_err, 2), "%", sep = "")
  cat("\nConfusion matrix:\n"); print(model$confusion)
})

setMethod("show", "H2OPCAModel", function(object) {
  print(object@data)
  cat("PCA Model Key:", object@key)
  
  model = object@model
  cat("\n\nStandard deviations:\n", model$sdev)
  cat("\n\nRotation:\n"); print(model$rotation)
})

setMethod("show", "H2OGBMModel", function(object) {
  print(object@data)
  cat("GBM Model Key:", object@key)
  
  model = object@model
  cat("\n\nConfusion matrix:\n"); print(model$confusion)
  cat("\nMean Squared error by tree:\n"); print(model$err)
})

setMethod("show", "H2OGBMGrid", function(object) {
  print(object@data)
  cat("GBMGrid Model Key:", object@key, "\n")
  
  temp = data.frame(t(sapply(object@sumtable, c)))
  cat("\nSummary\n"); print(temp)
})

setMethod("+", c("H2OParsedData", "H2OParsedData"), function(e1, e2) { h2o.__operator("+", e1, e2) })
setMethod("-", c("H2OParsedData", "H2OParsedData"), function(e1, e2) { h2o.__operator("-", e1, e2) })
setMethod("*", c("H2OParsedData", "H2OParsedData"), function(e1, e2) { h2o.__operator("*", e1, e2) })
setMethod("/", c("H2OParsedData", "H2OParsedData"), function(e1, e2) { h2o.__operator("/", e1, e2) })
setMethod("%%", c("H2OParsedData", "H2OParsedData"), function(e1, e2) { h2o.__operator("%", e1, e2) })
setMethod("==", c("H2OParsedData", "H2OParsedData"), function(e1, e2) { h2o.__operator("==", e1, e2) })
setMethod(">", c("H2OParsedData", "H2OParsedData"), function(e1, e2) { h2o.__operator(">", e1, e2) })
setMethod("<", c("H2OParsedData", "H2OParsedData"), function(e1, e2) { h2o.__operator("<", e1, e2) })
setMethod("!=", c("H2OParsedData", "H2OParsedData"), function(e1, e2) { h2o.__operator("!=", e1, e2) })
setMethod(">=", c("H2OParsedData", "H2OParsedData"), function(e1, e2) { h2o.__operator(">=", e1, e2) })
setMethod("<=", c("H2OParsedData", "H2OParsedData"), function(e1, e2) { h2o.__operator("<=", e1, e2) })

setMethod("+", c("numeric", "H2OParsedData"), function(e1, e2) { h2o.__operator("+", e1, e2) })
setMethod("-", c("numeric", "H2OParsedData"), function(e1, e2) { h2o.__operator("-", e1, e2) })
setMethod("*", c("numeric", "H2OParsedData"), function(e1, e2) { h2o.__operator("*", e1, e2) })
setMethod("/", c("numeric", "H2OParsedData"), function(e1, e2) { h2o.__operator("/", e1, e2) })
setMethod("%%", c("numeric", "H2OParsedData"), function(e1, e2) { h2o.__operator("%", e1, e2) })
setMethod("==", c("numeric", "H2OParsedData"), function(e1, e2) { h2o.__operator("==", e1, e2) })
setMethod(">", c("numeric", "H2OParsedData"), function(e1, e2) { h2o.__operator(">", e1, e2) })
setMethod("<", c("numeric", "H2OParsedData"), function(e1, e2) { h2o.__operator("<", e1, e2) })
setMethod("!=", c("numeric", "H2OParsedData"), function(e1, e2) { h2o.__operator("!=", e1, e2) })
setMethod(">=", c("numeric", "H2OParsedData"), function(e1, e2) { h2o.__operator(">=", e1, e2) })
setMethod("<=", c("numeric", "H2OParsedData"), function(e1, e2) { h2o.__operator("<=", e1, e2) })

setMethod("+", c("H2OParsedData", "numeric"), function(e1, e2) { h2o.__operator("+", e1, e2) })
setMethod("-", c("H2OParsedData", "numeric"), function(e1, e2) { h2o.__operator("-", e1, e2) })
setMethod("*", c("H2OParsedData", "numeric"), function(e1, e2) { h2o.__operator("*", e1, e2) })
setMethod("/", c("H2OParsedData", "numeric"), function(e1, e2) { h2o.__operator("/", e1, e2) })
setMethod("%%", c("H2OParsedData", "numeric"), function(e1, e2) { h2o.__operator("%", e1, e2) })
setMethod("==", c("H2OParsedData", "numeric"), function(e1, e2) { h2o.__operator("==", e1, e2) })
setMethod(">", c("H2OParsedData", "numeric"), function(e1, e2) { h2o.__operator(">", e1, e2) })
setMethod("<", c("H2OParsedData", "numeric"), function(e1, e2) { h2o.__operator("<", e1, e2) })
setMethod("!=", c("H2OParsedData", "numeric"), function(e1, e2) { h2o.__operator("!=", e1, e2) })
setMethod(">=", c("H2OParsedData", "numeric"), function(e1, e2) { h2o.__operator(">=", e1, e2) })
setMethod("<=", c("H2OParsedData", "numeric"), function(e1, e2) { h2o.__operator("<=", e1, e2) })

setMethod("min", "H2OParsedData", function(x) { h2o.__func("min", x, "Number") })
setMethod("max", "H2OParsedData", function(x) { h2o.__func("max", x, "Number") })
setMethod("mean", "H2OParsedData", function(x) { h2o.__func("mean", x, "Number") })
setMethod("sum", "H2OParsedData", function(x) { h2o.__func("sum", x, "Number") })
setMethod("log2", "H2OParsedData", function(x) { h2o.__func("log", x, "Vector") })

setMethod("[", "H2OParsedData", function(x, i, j, ..., drop = TRUE) {
  # Currently, you can only select one column at a time
  if(!missing(j) && length(j) > 1) stop("Currently, can only select one column at a time")
  if(missing(i) && missing(j)) return(x)
  if(missing(i) && !missing(j)) {
    if(is.character(j)) return(do.call("$", c(x, j)))
    expr = paste(h2o.__escape(x@key), "[", j-1, "]", sep="")
  } else {
    if(class(i) == "H2OLogicalData") {
      opt = paste(h2o.__escape(x@key), h2o.__escape(i@key), sep=",")
      if(missing(j))
        expr = paste("filter(", opt, ")", sep="")
      else if(is.character(j))
        expr = paste("filter(", opt, ")$", j, sep="")
      else if(is.numeric(j))
        expr = paste("filter(", opt, ")[", j-1, "]", sep="")
      else stop("Rows must be numeric or column names")
    }
    else if(is.numeric(i)) {
      start = min(i); i_off = i - start + 1;
      opt = paste(h2o.__escape(x@key), start-1, max(i_off), sep=",")
      if(missing(j))
        expr = paste("slice(", opt, ")", sep="")
      else if(is.character(j))
        expr = paste("slice(", opt, ")$", j, sep="")
      else if(is.numeric(j))
        expr = paste("slice(", opt, ")[", j-1, "]", sep="")
    } else stop("Rows must be numeric or column names")
  }
  res = h2o.__exec(x@h2o, expr)
  new("H2OParsedData", h2o=x@h2o, key=res)
})

setMethod("$", "H2OParsedData", function(x, name) {
  myNames = names(x)
  if(!(name %in% myNames)) {
    print(paste("Column", as.character(name), "not present in expression")); return(NULL)
  } else {
    # x[match(name, myNames)]
    expr = paste(h2o.__escape(x@key), "$", name, sep="")
    res = h2o.__exec(x@h2o, expr)
    new("H2OParsedData", h2o=x@h2o, key=res)
  }
})

setMethod("colnames", "H2OParsedData", function(x) {
  res = h2o.__remoteSend(x@h2o, h2o.__PAGE_INSPECT, key=x@key)
  unlist(lapply(res$cols, function(y) y$name))
})

setMethod("names", "H2OParsedData", function(x) { colnames(x) })

setMethod("nrow", "H2OParsedData", function(x) { 
  res = h2o.__remoteSend(x@h2o, h2o.__PAGE_INSPECT, key=x@key); as.numeric(res$num_rows) })

setMethod("ncol", "H2OParsedData", function(x) {
  res = h2o.__remoteSend(x@h2o, h2o.__PAGE_INSPECT, key=x@key); as.numeric(res$num_cols) })

setMethod("dim", "H2OParsedData", function(x) {
  res = h2o.__remoteSend(x@h2o, h2o.__PAGE_INSPECT, key=x@key)
  as.numeric(c(res$num_rows, res$num_cols))
})

setMethod("summary", "H2OParsedData", function(object) {
  res = h2o.__remoteSend(object@h2o, h2o.__PAGE_SUMMARY, key=object@key)
  res = res$summary$columns
  result = NULL; cnames = NULL
  for(i in 1:length(res)) {
    cnames = c(cnames, paste("      ", res[[i]]$name, sep=""))
    if(res[[i]]$type == "number") {
      if(is.null(res[[i]]$min) || length(res[[i]]$min) == 0) res[[i]]$min = NaN
      if(is.null(res[[i]]$max) || length(res[[i]]$max) == 0) res[[i]]$max = NaN
      if(is.null(res[[i]]$mean) || length(res[[i]]$mean) == 0) res[[i]]$mean = NaN
      if(is.null(res[[i]]$percentiles))
        params = format(rep(round(as.numeric(res[[i]]$mean), 3), 6), nsmall = 3)
      else
        params = format(round(as.numeric(c(res[[i]]$min[1], res[[i]]$percentiles$values[4], res[[i]]$percentiles$values[6], res[[i]]$mean, res[[i]]$percentiles$values[8], res[[i]]$max[1])), 3), nsmall = 3)
      result = cbind(result, c(paste("Min.   :", params[1], "  ", sep=""), paste("1st Qu.:", params[2], "  ", sep=""),
                               paste("Median :", params[3], "  ", sep=""), paste("Mean   :", params[4], "  ", sep=""),
                               paste("3rd Qu.:", params[5], "  ", sep=""), paste("Max.   :", params[6], "  ", sep="")))                 
    }
    else if(res[[i]]$type == "enum") {
      col = matrix(rep("", 6), ncol=1)
      len = length(res[[i]]$histogram$bins)
      for(j in 1:min(6,len))
        col[j] = paste(res[[i]]$histogram$bin_names[len-j+1], ": ", res[[i]]$histogram$bins[len-j+1], sep="")
      result = cbind(result, col)
    }
  }
  result = as.table(result)
  rownames(result) <- rep("", 6)
  colnames(result) <- cnames
  result
})

setMethod("summary", "H2OPCAModel", function(object) {
  # TODO: Save propVar and cumVar from the Java output instead of computing here
  myVar = object@model$sdev^2
  myProp = myVar/sum(myVar)
  result = rbind(object@model$sdev, myProp, cumsum(myProp))   # Need to limit decimal places to 4
  colnames(result) = paste("PC", seq(1, length(myVar)), sep="")
  rownames(result) = c("Standard deviation", "Proportion of Variance", "Cumulative Proportion")
  
  cat("Importance of components:\n")
  print(result)
})

setMethod("as.data.frame", "H2OParsedData", function(x) {
  url <- paste('http://', x@h2o@ip, ':', x@h2o@port, '/2/DownloadDataset?src_key=', x@key, sep='')
  ttt <- getURL(url)
  read.csv(textConnection(ttt))
})

setMethod("head", "H2OParsedData", function(x, n = 6L, ...) {
  if(n == 0 || !is.numeric(n)) stop("n must be a non-zero integer")
  n = round(n)
  # if(abs(n) > nrow(x)) stop(paste("n must be between 1 and", nrow(x)))
  numRows = nrow(x)
  if(n < 0 && abs(n) >= numRows) return(data.frame())
  myView = ifelse(n > 0, min(n, numRows), numRows+n)
  if(myView > MAX_INSPECT_VIEW) stop(paste("Cannot view more than", MAX_INSPECT_VIEW, "rows"))
  
  res = h2o.__remoteSend(x@h2o, h2o.__PAGE_INSPECT, key=x@key, offset=0, view=myView)
  temp = unlist(lapply(res$rows, function(y) { y$row = NULL; y }))
  if(is.null(temp)) return(temp)
  x.df = data.frame(matrix(temp, nrow = myView, byrow = TRUE))
  colnames(x.df) = unlist(lapply(res$cols, function(y) y$name))
  x.df
  
  # if(n > 0) as.data.frame(x[1:n,])
  # else as.data.frame(x[1:(nrow(x)+n),])
})

setMethod("tail", "H2OParsedData", function(x, n = 6L, ...) {
  if(n == 0 || !is.numeric(n)) stop("n must be a non-zero integer")
  n = round(n)
  # if(abs(n) > nrow(x)) stop(paste("n must be between 1 and", nrow(x)))
  numRows = nrow(x)
  if(n < 0 && abs(n) >= numRows) return(data.frame())
  myOff = ifelse(n > 0, max(0, numRows-n), abs(n))
  myView = ifelse(n > 0, min(n, numRows), numRows+n)
  if(myView > MAX_INSPECT_VIEW) stop(paste("Cannot view more than", MAX_INSPECT_VIEW, "rows"))
  
  res = h2o.__remoteSend(x@h2o, h2o.__PAGE_INSPECT, key=x@key, offset=myOff, view=myView)
  temp = unlist(lapply(res$rows, function(y) { y$row = NULL; y }))
  if(is.null(temp)) return(temp)
  x.df = data.frame(matrix(temp, nrow = myView, byrow = TRUE))
  colnames(x.df) = unlist(lapply(res$cols, function(y) y$name))
  x.df
  
  # if(n > 0) opt = paste(h2o.__escape(x@key), nrow(x)-n, sep=",")
  # else opt = paste(h2o.__escape(x@key), abs(n), sep=",")
  # res = h2o.__exec(x@h2o, paste("slice(", opt, ")", sep=""))
  # as.data.frame(new("H2OParsedData", h2o=x@h2o, key=res))
})

setMethod("plot", "H2OPCAModel", function(x, y, ...) {
  barplot(x@model$sdev^2)
  title(main = paste("h2o.prcomp(", x@data@key, ")", sep=""), ylab = "Variances")
})

setGeneric("h2o.factor", function(data, col) { standardGeneric("h2o.factor") })
setMethod("h2o.factor", signature(data="H2OParsedData", col="numeric"),
   function(data, col) {
     if(col < 1 || col > ncol(data)) stop("col must be between 1 and ", ncol(data))
     col = col - 1
      newCol = paste("factor(", h2o.__escape(data@key), "[", col, "])", sep="")
      expr = paste("colSwap(", h2o.__escape(data@key), ",", col, ",", newCol, ")", sep="")
      res = h2o.__exec_dest_key(data@h2o, expr, destKey=data@key)
      data
})

setMethod("h2o.factor", signature(data="H2OParsedData", col="character"), 
   function(data, col) {
      ind = match(col, colnames(data))
      if(is.na(ind)) stop("Column ", col, " does not exist in ", data@key)
      h2o.factor(data, ind-1)
})

#------------------------------------ FluidVecs ----------------------------------------#
setMethod("show", "H2ORawData2", function(object) {
  print(object@h2o)
  cat("Raw Data Key:", object@key, "\n")
})

setMethod("show", "H2OParsedData2", function(object) {
  print(object@h2o)
  cat("Parsed Data Key:", object@key, "\n")
  if(ncol(object) <= 1000) print(head(object))
})

setMethod("[", "H2OParsedData2", function(x, i, j, ..., drop = TRUE) {
  # if(!missing(j) && length(j) > 1) stop("Currently, can only select one column at a time")
  # if(!missing(i) && length(i) > 1) stop("Currently, can only select one row at a time")
  numRows = nrow(x); numCols = ncol(x)
  if((!missing(i) && is.numeric(i) && any(abs(i) < 1 || abs(i) > numRows)) || 
     (!missing(j) && is.numeric(j) && any(abs(j) < 1 || abs(j) > numCols)))
    stop("Array index out of bounds!")
  
  if(missing(i) && missing(j)) return(x)
  if(missing(i) && !missing(j)) {
    if(is.character(j)) return(do.call("$", c(x, j)))
    if(is.logical(j)) j = -which(!j)
    if(class(j) == "H2OLogicalData2")
      expr = paste(x@key, "[", j@key, ",]", sep="")
    else if(is.numeric(j)) {
      if(length(j) == 1)
        expr = paste(x@key, "[,", j, "]", sep="")
      else
        expr = paste(x@key, "[,c(", paste(j, collapse=","), ")]", sep="")
    } else stop(paste("Column index of type", class(j), "unsupported!"))
  } else if(!missing(i) && missing(j)) {
    # if(is.logical(i)) i = -which(!i)
    if(is.logical(i)) i = which(i)
    # if(!is.numeric(i)) stop("Row index must be numeric")
    if(class(i) == "H2OLogicalData2")
      expr = paste(x@key, "[", i@key, ",]", sep="")
    else if(is.numeric(i)) {
      if(length(i) == 1)
        expr = paste(x@key, "[", i, ",]", sep="")
      else
        expr = paste(x@key, "[c(", paste(i, collapse=","), "),]", sep="")
    } else stop(paste("Row index of type", class(i), "unsupported!"))
  } else {
    # if(is.logical(i)) i = -which(!i)
    if(is.logical(i)) i = which(i)
    # if(!is.numeric(i)) stop("Row index must be numeric")
    else if(class(i) == "H2OLogicalData2") rind = i@key
    else if(!is.numeric(i)) stop(paste("Row index of type", class(i), "unsupported!"))
    rind = ifelse(length(i) == 1, i, paste("c(", paste(i, collapse=","), ")", sep=""))
    
    if(class(j) == "H2OLogicalData2") cind = j@key
    else if(is.logical(j)) j = -which(!j)
    else if(!is.numeric(j) && !is.character(j)) stop(paste("Column index of type", class(j), "unsupported!"))
    
    if(is.numeric(j))
      cind = ifelse(length(j) == 1, j, paste("c(", paste(j, collapse=","), ")", sep=""))
    else if(is.character(j)) {
      myCol = colnames(x)
      if(any(!(j %in% myCol))) stop(paste(paste(j[which(!(j %in% myCol))], collapse=','), 'is not a valid column name'))
      j_num = match(j, myCol)
      cind = ifelse(length(j) == 1, j_num, paste("c(", paste(j_num, collapse=","), ")", sep=""))
    }
    expr = paste(x@key, "[", rind, ",", cind, "]", sep="")
  }
  res = h2o.__exec2(x@h2o, expr)
  if(res$num_rows == 0 && res$num_cols == 0)
    res$scalar
  else
    new("H2OParsedData2", h2o=x@h2o, key=res$dest_key)
})

setMethod("$", "H2OParsedData2", function(x, name) {
  myNames = colnames(x)
  if(!(name %in% myNames)) return(NULL)
  cind = which(name == myNames)
  expr = paste(x@key, "[,", cind, "]", sep="")
  res = h2o.__exec2(x@h2o, expr)
  if(res$num_rows == 0 && res$num_cols == 0)
    res$scalar
  else
    new("H2OParsedData2", h2o=x@h2o, key=res$dest_key)
})

setMethod("+", c("H2OParsedData2", "H2OParsedData2"), function(e1, e2) { h2o.__binop2("+", e1, e2) })
setMethod("-", c("H2OParsedData2", "H2OParsedData2"), function(e1, e2) { h2o.__binop2("-", e1, e2) })
setMethod("*", c("H2OParsedData2", "H2OParsedData2"), function(e1, e2) { h2o.__binop2("*", e1, e2) })
setMethod("/", c("H2OParsedData2", "H2OParsedData2"), function(e1, e2) { h2o.__binop2("/", e1, e2) })
setMethod("%%", c("H2OParsedData2", "H2OParsedData2"), function(e1, e2) { h2o.__binop2("%", e1, e2) })
setMethod("==", c("H2OParsedData2", "H2OParsedData2"), function(e1, e2) { h2o.__binop2("==", e1, e2) })
setMethod(">", c("H2OParsedData2", "H2OParsedData2"), function(e1, e2) { h2o.__binop2(">", e1, e2) })
setMethod("<", c("H2OParsedData2", "H2OParsedData2"), function(e1, e2) { h2o.__binop2("<", e1, e2) })
setMethod("!=", c("H2OParsedData2", "H2OParsedData2"), function(e1, e2) { h2o.__binop2("!=", e1, e2) })
setMethod(">=", c("H2OParsedData2", "H2OParsedData2"), function(e1, e2) { h2o.__binop2(">=", e1, e2) })
setMethod("<=", c("H2OParsedData2", "H2OParsedData2"), function(e1, e2) { h2o.__binop2("<=", e1, e2) })
setMethod("&", c("H2OParsedData2", "H2OParsedData2"), function(e1, e2) {h2o.__binop2("&&", e1, e2) })
setMethod("|", c("H2OParsedData2", "H2OParsedData2"), function(e1, e2) {h2o.__binop2("||", e1, e2) })

setMethod("+", c("numeric", "H2OParsedData2"), function(e1, e2) { h2o.__binop2("+", e1, e2) })
setMethod("-", c("numeric", "H2OParsedData2"), function(e1, e2) { h2o.__binop2("-", e1, e2) })
setMethod("*", c("numeric", "H2OParsedData2"), function(e1, e2) { h2o.__binop2("*", e1, e2) })
setMethod("/", c("numeric", "H2OParsedData2"), function(e1, e2) { h2o.__binop2("/", e1, e2) })
setMethod("%%", c("numeric", "H2OParsedData2"), function(e1, e2) { h2o.__binop2("%", e1, e2) })
setMethod("==", c("numeric", "H2OParsedData2"), function(e1, e2) { h2o.__binop2("==", e1, e2) })
setMethod(">", c("numeric", "H2OParsedData2"), function(e1, e2) { h2o.__binop2(">", e1, e2) })
setMethod("<", c("numeric", "H2OParsedData2"), function(e1, e2) { h2o.__binop2("<", e1, e2) })
setMethod("!=", c("numeric", "H2OParsedData2"), function(e1, e2) { h2o.__binop2("!=", e1, e2) })
setMethod(">=", c("numeric", "H2OParsedData2"), function(e1, e2) { h2o.__binop2(">=", e1, e2) })
setMethod("<=", c("numeric", "H2OParsedData2"), function(e1, e2) { h2o.__binop2("<=", e1, e2) })
setMethod("&", c("numeric", "H2OParsedData2"), function(e1, e2) {h2o.__binop2("&&", e1, e2) })
setMethod("|", c("numeric", "H2OParsedData2"), function(e1, e2) {h2o.__binop2("||", e1, e2) })

setMethod("+", c("H2OParsedData2", "numeric"), function(e1, e2) { h2o.__binop2("+", e1, e2) })
setMethod("-", c("H2OParsedData2", "numeric"), function(e1, e2) { h2o.__binop2("-", e1, e2) })
setMethod("*", c("H2OParsedData2", "numeric"), function(e1, e2) { h2o.__binop2("*", e1, e2) })
setMethod("/", c("H2OParsedData2", "numeric"), function(e1, e2) { h2o.__binop2("/", e1, e2) })
setMethod("%%", c("H2OParsedData2", "numeric"), function(e1, e2) { h2o.__binop2("%", e1, e2) })
setMethod("==", c("H2OParsedData2", "numeric"), function(e1, e2) { h2o.__binop2("==", e1, e2) })
setMethod(">", c("H2OParsedData2", "numeric"), function(e1, e2) { h2o.__binop2(">", e1, e2) })
setMethod("<", c("H2OParsedData2", "numeric"), function(e1, e2) { h2o.__binop2("<", e1, e2) })
setMethod("!=", c("H2OParsedData2", "numeric"), function(e1, e2) { h2o.__binop2("!=", e1, e2) })
setMethod(">=", c("H2OParsedData2", "numeric"), function(e1, e2) { h2o.__binop2(">=", e1, e2) })
setMethod("<=", c("H2OParsedData2", "numeric"), function(e1, e2) { h2o.__binop2("<=", e1, e2) })
setMethod("&", c("H2OParsedData2", "numeric"), function(e1, e2) {h2o.__binop2("&&", e1, e2) })
setMethod("|", c("H2OParsedData2", "numeric"), function(e1, e2) {h2o.__binop2("||", e1, e2) })

setMethod("!", "H2OParsedData2", function(x) { h2o.__unop2("!", x) })
setMethod("abs", "H2OParsedData2", function(x) { h2o.__unop2("abs", x) })
setMethod("sign", "H2OParsedData2", function(x) { h2o.__unop2("sgn", x) })
setMethod("sqrt", "H2OParsedData2", function(x) { h2o.__unop2("sqrt", x) })
setMethod("ceiling", "H2OParsedData2", function(x) { h2o.__unop2("ceil", x) })
setMethod("floor", "H2OParsedData2", function(x) { h2o.__unop2("floor", x) })
setMethod("log", "H2OParsedData2", function(x) { h2o.__unop2("log", x) })
setMethod("exp", "H2OParsedData2", function(x) { h2o.__unop2("exp", x) })
setMethod("sum", "H2OParsedData2", function(x) { h2o.__unop2("sum", x) })
setMethod("is.na", "H2OParsedData2", function(x) { h2o.__unop2("is.na", x) })

setGeneric("h2o.cut", function(x, breaks) { standardGeneric("h2o.cut") })
setMethod("h2o.cut", signature(x="H2OParsedData2", breaks="numeric"), function(x, breaks) {
  nums = ifelse(length(breaks) == 1, breaks, paste("c(", paste(breaks, collapse=","), ")", sep=""))
  expr = paste("cut(", x@key, ",", nums, ")", sep="")
  res = h2o.__exec2(x@h2o, expr)
  if(res$num_rows == 0 && res$num_cols == 0)   # TODO: If logical operator, need to indicate
    return(res$scalar)
  new("H2OParsedData2", h2o=x@h2o, key=res$dest_key)
})

setGeneric("h2o.table", function(x) { standardGeneric("h2o.table") })
setMethod("h2o.table", signature(x="H2OParsedData2"), function(x) { h2o.__unop2("table", x) })

setMethod("colnames", "H2OParsedData2", function(x) {
  res = h2o.__remoteSend(x@h2o, h2o.__PAGE_INSPECT2, src_key=x@key)
  unlist(lapply(res$cols, function(y) y$name))
})

setMethod("names", "H2OParsedData2", function(x) { colnames(x) })

setMethod("nrow", "H2OParsedData2", function(x) { 
  res = h2o.__remoteSend(x@h2o, h2o.__PAGE_INSPECT2, src_key=x@key); as.numeric(res$numRows) })

setMethod("ncol", "H2OParsedData2", function(x) {
  res = h2o.__remoteSend(x@h2o, h2o.__PAGE_INSPECT2, src_key=x@key); as.numeric(res$numCols) })

setMethod("min", "H2OParsedData2", function(x) {
  res = h2o.__remoteSend(x@h2o, h2o.__PAGE_INSPECT2, src_key=x@key)
  min(sapply(res$cols, function(x) { x$min }))
})

setMethod("max", "H2OParsedData2", function(x) {
  res = h2o.__remoteSend(x@h2o, h2o.__PAGE_INSPECT2, src_key=x@key)
  max(sapply(res$cols, function(x) { x$max }))
})

setMethod("range", "H2OParsedData2", function(x) {
  res = h2o.__remoteSend(x@h2o, h2o.__PAGE_INSPECT2, src_key=x@key)
  temp = sapply(res$cols, function(x) { c(x$min, x$max) })
  c(min(temp[1,]), max(temp[2,]))
})

setMethod("colMeans", "H2OParsedData2", function(x) {
  res = h2o.__remoteSend(x@h2o, h2o.__PAGE_INSPECT2, src_key=x@key)
  temp = sapply(res$cols, function(x) { x$mean })
  names(temp) = sapply(res$cols, function(x) { x$name })
  temp
})

setMethod("dim", "H2OParsedData2", function(x) {
  res = h2o.__remoteSend(x@h2o, h2o.__PAGE_INSPECT2, src_key=x@key)
  as.numeric(c(res$numRows, res$numCols))
})

setMethod("as.data.frame", "H2OParsedData2", function(x) {
  as.data.frame(new("H2OParsedData", h2o=x@h2o, key=x@key))
})

setMethod("head", "H2OParsedData2", function(x, n = 6L, ...) { 
  head(new("H2OParsedData", h2o=x@h2o, key=x@key), n, ...)
})

setMethod("tail", "H2OParsedData2", function(x, n = 6L, ...) {
  tail(new("H2OParsedData", h2o=x@h2o, key=x@key), n, ...)
})

setMethod("is.factor", "H2OParsedData2", function(x) {
  res = h2o.__remoteSend(x@h2o, h2o.__PAGE_SUMMARY2, source=x@key)
  temp = sapply(res$summaries, function(x) { is.null(x$domains) })
  return(!any(temp))
})

setMethod("quantile", "H2OParsedData2", function(x) {
  res = h2o.__remoteSend(x@h2o, h2o.__PAGE_SUMMARY2, source=x@key)
  temp = sapply(res$summaries, function(x) { x$percentileValues })
  filt = !sapply(temp, is.null)
  temp = temp[filt]
  if(length(temp) == 0) return(NULL)
  
  myFeat = res$names[filt[1:length(res$names)]]
  myQuantiles = c(1, 5, 10, 25, 33, 50, 66, 75, 90, 95, 99)
  matrix(unlist(temp), ncol = length(res$names), dimnames = list(paste(myQuantiles, "%", sep=""), myFeat))
})

histograms <- function(object) { UseMethod("histograms", object) }
setMethod("histograms", "H2OParsedData2", function(object) {
  res = h2o.__remoteSend(object@h2o, h2o.__PAGE_SUMMARY2, source=object@key)
  list.of.bins <- lapply(res$summaries, function(res) {
    if (res$type == 'Enum') {
      bins <- NULL
    } else {
      counts <- res$hcnt
      breaks <- seq(res$hstart, by=res$hstep, length.out=length(res$hcnt) + 1)
      bins <- list(counts,breaks)
      names(bins) <- cbind('counts', 'breaks')
    }
    bins
  })
})

setMethod("summary", "H2OParsedData2", function(object) {
  res = h2o.__remoteSend(object@h2o, h2o.__PAGE_SUMMARY2, source=object@key)
  cols <- sapply(res$summaries, function(col) {
    if(col$type != 'Enum') { # numeric column
      if(is.null(col$stats$mins) || length(col$stats$mins) == 0) col$stats$mins = NaN
      if(is.null(col$stats$maxs) || length(col$stats$maxs) == 0) col$stats$maxs = NaN
      if(is.null(col$stats$pctile))
        params = format(rep(round(as.numeric(col$stats$mean), 3), 6), nsmall = 3)
      else
        params = format(round(as.numeric(c(
          col$stats$mins[1],
          col$stats$pctile[4],
          col$stats$pctile[6],
          col$stats$mean,
          col$stats$pctile[8],
          col$stats$maxs[1])), 3), nsmall = 3)
      result = c(paste("Min.   :", params[1], "  ", sep=""), paste("1st Qu.:", params[2], "  ", sep=""),
                 paste("Median :", params[3], "  ", sep=""), paste("Mean   :", params[4], "  ", sep=""),
                 paste("3rd Qu.:", params[5], "  ", sep=""), paste("Max.   :", params[6], "  ", sep="")) 
    }
    else {
      top.ix <- sort.int(col$hcnt, decreasing=T, index.return=T)$ix[1:6]
      domains <- col$hbrk[top.ix]
      counts <- col$hcnt[top.ix]
      width <- max(cbind(nchar(domains), nchar(counts)))
      result <- paste(domains,
                      mapply(function(x, y) { paste(rep(' ',max(width + 1 - nchar(x) - nchar(y),0)), collapse='') }, domains, counts),
                      ":",
                      counts,
                      " ",
                      sep='')
      result[is.na(top.ix)] <- NA
      result
    }
  })
  
  result = as.table(cols)
  rownames(result) <- rep("", 6)
  colnames(result) <- sapply(res$summaries, function(col) col$colname)
  result
})

setMethod("apply", "H2OParsedData2", function(X, MARGIN, FUN, ...) {
  params = c(X@key, MARGIN, paste(deparse(substitute(FUN)), collapse=""))
  expr = paste("apply(", paste(params, collapse=","), ")", sep="")
  res = h2o.__exec2(X@h2o, expr)
  new("H2OParsedData2", h2o=X@h2o, key=res$dest_key)
})
