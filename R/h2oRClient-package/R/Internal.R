# Hack to get around Exec.json always dumping to same Result.hex key
# TODO: Need better way to manage temporary/intermediate values in calculations! Right now, overwriting occurs silently
pkg.env = new.env()
pkg.env$result_count = 0
pkg.env$temp_count = 0
pkg.env$IS_LOGGING = FALSE
TEMP_KEY = "Last.value"
RESULT_MAX = 200
LOGICAL_OPERATORS = c("==", ">", "<", "!=", ">=", "<=", "&&", "||", "!")

# Initialize functions for R logging
myPath = paste(Sys.getenv("HOME"), "Library/Application Support/h2o", sep="/")
if(Sys.info()["sysname"] == "Windows")
  myPath = paste(Sys.getenv("APPDATA"), "h2o", sep="/")
h2o.__LOG_COMMAND = paste(myPath, "h2o_commands.log", sep="/")
h2o.__LOG_ERROR = paste(myPath, "h2o_error_json.log", sep="/")
h2o.__startLogging <- function() { assign("IS_LOGGING", TRUE, envir = pkg.env) }
h2o.__stopLogging <- function() { assign("IS_LOGGING", FALSE, envir = pkg.env) }
h2o.__clearLogs <- function() { unlink(h2o.__LOG_COMMAND); unlink(h2o.__LOG_ERROR) }
h2o.__openCmdLog <- function() {
  myOS = Sys.info()["sysname"]
  if(myOS == "Windows") shell.exec(paste("open '", h2o.__LOG_COMMAND, "'", sep="")) 
  else system(paste("open '", h2o.__LOG_COMMAND, "'", sep=""))
}
h2o.__openErrLog <- function() {
  myOS = Sys.info()["sysname"]
  if(myOS == "Windows") shell.exec(paste("open '", h2o.__LOG_ERROR, "'", sep="")) 
  else system(paste("open '", h2o.__LOG_ERROR, "'", sep=""))
}

# Internal functions & declarations
h2o.__PAGE_CLOUD = "Cloud.json"
h2o.__PAGE_EXEC = "Exec.json"
h2o.__PAGE_GET = "GetVector.json"
h2o.__PAGE_IMPORTURL = "ImportUrl.json"
h2o.__PAGE_IMPORTFILES = "ImportFiles.json"
h2o.__PAGE_IMPORTFILES2 = "2/ImportFiles2.json"
h2o.__PAGE_IMPORTHDFS = "ImportHdfs.json"
h2o.__PAGE_INSPECT = "Inspect.json"
h2o.__PAGE_INSPECT2 = "2/Inspect2.json"
h2o.__PAGE_JOBS = "Jobs.json"
h2o.__PAGE_PARSE = "Parse.json"
h2o.__PAGE_PARSE2 = "2/Parse2.json"
h2o.__PAGE_PUT = "PutVector.json"
h2o.__PAGE_REMOVE = "Remove.json"
h2o.__PAGE_VIEWALL = "StoreView.json"
h2o.__DOWNLOAD_LOGS = "LogDownload.json"

h2o.__PAGE_SUMMARY = "SummaryPage.json"
h2o.__PAGE_SUMMARY2 = "2/SummaryPage2.json"
h2o.__PAGE_PREDICT = "GeneratePredictionsPage.json"
h2o.__PAGE_PREDICT2 = "2/Predict.json"
h2o.__PAGE_COLNAMES = "SetColumnNames.json"
h2o.__PAGE_PCA = "2/PCA.json"
h2o.__PAGE_PCASCORE = "2/PCAScore.json"
h2o.__PAGE_GLM = "GLM.json"
h2o.__PAGE_KMEANS = "KMeans.json"
h2o.__PAGE_KMAPPLY = "KMeansApply.json"
h2o.__PAGE_KMSCORE = "KMeansScore.json"
h2o.__PAGE_RF  = "RF.json"
h2o.__PAGE_RFVIEW = "RFView.json"
h2o.__PAGE_RFTREEVIEW = "RFTreeView.json"
h2o.__PAGE_GLMGrid = "GLMGrid.json"
h2o.__PAGE_GLMGridProgress = "GLMGridProgress.json"
h2o.__PAGE_GBM = "2/GBM.json"
h2o.__PAGE_GBMGrid = "2/GBMGrid.json"
h2o.__PAGE_GBMModelView = "2/GBMModelView.json"

h2o.__PAGE_GLM2 = "2/GLM2.json"
h2o.__PAGE_GLMModelView = "2/GLMModelView.json"
h2o.__PAGE_GLMValidView = "2/GLMValidationView.json"
h2o.__PAGE_FVEXEC = "2/DataManip.json"     # This is temporary until FluidVec Exec query is finished!
h2o.__PAGE_EXEC2 = "2/Exec2.json"
h2o.__PAGE_PCAModelView = "2/PCAModelView.json"
h2o.__PAGE_NN = "2/NeuralNet.json"
h2o.__PAGE_NNModelView = "2/ExportModel.json"


h2o.__remoteSend <- function(client, page, ...) {
  ip = client@ip
  port = client@port
  myURL = paste("http://", ip, ":", port, "/", page, sep="")
  
  # Log list of parameters sent to H2O
  if(pkg.env$IS_LOGGING) {
    # print(substitute(list(...)))
    # temp = deparse(substitute(list(...)))
    # write(paste(myURL, '\t', temp), file = h2o.__LOG_COMMAND, append = TRUE)
    temp = list(...); temp = get("temp"); nams = names(temp)
    str = rep(" ", length(temp))
    for(i in seq_along(temp))
      str[i] = paste(nams[i], ": ", temp[[i]], sep="")
    str = paste(myURL, '\t', paste(str, collapse=", "))
    write(str, file = h2o.__LOG_COMMAND, append = TRUE)
  }
  
  # TODO (Spencer): Create "commands.log" using: list(...)
  # Sends the given arguments as URL arguments to the given page on the specified server
  # temp = postForm(myURL, style = "POST", ...)
  if(length(list(...)) == 0)
    temp = getURLContent(myURL)
  else
    temp = getForm(myURL, ..., .checkParams = FALSE)   # Some H2O params overlap with Curl params
  # after = gsub("\\\\\\\"NaN\\\\\\\"", "NaN", temp[1]) 
  # after = gsub("NaN", "\"NaN\"", after)
  # after = gsub("-Infinity", "\"-Inf\"", temp[1])
  # after = gsub("Infinity", "\"Inf\"", after)
  after = gsub('"Infinity"', '"Inf"', temp[1])
  after = gsub('"-Infinity"', '"-Inf"', after)
  res = fromJSON(after)
  
  if (!is.null(res$error)) {
    if(pkg.env$IS_LOGGING) h2o.__writeToFile(res, h2o.__LOG_ERROR)
    stop(paste(myURL," returned the following error:\n", h2o.__formatError(res$error)))
  }
  res
}

h2o.__writeToFile <- function(res, fileName) {
  formatVector = function(vec) {
    result = rep(" ", length(vec))
    nams = names(vec)
    for(i in 1:length(vec))
      result[i] = paste(nams[i], ": ", vec[i], sep="")
    paste(result, collapse="\n")
  }
  
  cat("Writing JSON response to", fileName)
  temp = strsplit(as.character(Sys.time()), " ")[[1]]
  # myDate = gsub("-", "", temp[1]); myTime = gsub(":", "", temp[2])
  write(paste(temp[1], temp[2], '\t', formatVector(unlist(res))), file = fileName, append = TRUE)
  # writeLines(unlist(lapply(res$response, paste, collapse=" ")), fileConn)
}

h2o.__formatError <- function(error,prefix="  ") {
  result = ""
  items = strsplit(error,"\n")[[1]];
  for (i in 1:length(items))
    result = paste(result,prefix,items[i],"\n",sep="")
  result
}

h2o.__dumpLogs <- function(client) {
  ip = client@ip
  port = client@port
  
  # Sends the given arguments as URL arguments to the given page on the specified server
  url = paste("http://", ip, ":", port, "/", h2o.__DOWNLOAD_LOGS, sep="")
  temp = strsplit(as.character(Sys.time()), " ")[[1]]
  myDate = gsub("-", "", temp[1]); myTime = gsub(":", "", temp[2])
  myFile = paste("h2ologs_", myDate, "_", myTime, ".zip", sep="")
  errorFolder = "h2o_error_logs"
  
  if(!file.exists(errorFolder)) dir.create(errorFolder)
  download.file(url, destfile = paste(getwd(), "h2o_error_logs", myFile, sep="/"))
}

h2o.__poll <- function(client, keyName) {
  res = h2o.__remoteSend(client, h2o.__PAGE_JOBS)
  res = res$jobs
  if(length(res) == 0) stop("No jobs found in queue")
  prog = NULL
  for(i in 1:length(res)) {
    if(res[[i]]$key == keyName)
      prog = res[[i]]
  }
  if(is.null(prog)) stop("Job key ", keyName, " not found in job queue")
  if(prog$cancelled) stop("Job key ", keyName, " has been cancelled")
  prog$progress
}

h2o.__allDone <- function(client) {
  res = h2o.__remoteSend(client, h2o.__PAGE_JOBS)
  notDone = lapply(res$jobs, function(x) { !(x$progress == -1.0 || x$cancelled) })
  !any(unlist(notDone))
}

h2o.__pollAll <- function(client, timeout) {
  start = Sys.time()
  while(!h2o.__allDone(client)) {
    Sys.sleep(1)
    if(as.numeric(difftime(Sys.time(), start)) > timeout)
      stop("Timeout reached! Check if any jobs have frozen in H2O.")
  }
}

h2o.__exec <- function(client, expr) {
  type = tryCatch({ typeof(expr) }, error = function(e) { "expr" })
  if (type != "character")
    expr = deparse(substitute(expr))
  destKey = paste("Result_", pkg.env$result_count, ".hex", sep="")
  res = h2o.__remoteSend(client, h2o.__PAGE_EXEC, expression=expr, destination_key=destKey)
  pkg.env$result_count = (pkg.env$result_count + 1) %% RESULT_MAX
  res$key
}

h2o.__exec_dest_key <- function(client, expr, destKey) {
  type = tryCatch({ typeof(expr) }, error = function(e) { "expr" })
  if (type != "character")
    expr = deparse(substitute(expr))
  res = h2o.__remoteSend(client, h2o.__PAGE_EXEC, expression=expr, destination_key=destKey)
  pkg.env$result_count = (pkg.env$result_count + 1) %% RESULT_MAX
  res$key
}

h2o.__operator <- function(op, x, y) {
  if(!((ncol(x) == 1 || class(x) == "numeric") && (ncol(y) == 1 || class(y) == "numeric")))
    stop("Can only operate on single column vectors")
  LHS = ifelse(class(x) == "H2OParsedData", h2o.__escape(x@key), x)
  RHS = ifelse(class(y) == "H2OParsedData", h2o.__escape(y@key), y)
  expr = paste(LHS, op, RHS)
  if(class(x) == "H2OParsedData") myClient = x@h2o
  else myClient = y@h2o
  res = h2o.__exec(myClient, expr)
  if(op %in% LOGICAL_OPERATORS)
    new("H2OLogicalData", h2o=myClient, key=res)
  else
    new("H2OParsedData", h2o=myClient, key=res)
}

h2o.__escape <- function(key) {
  key_esc = key
  myOS = Sys.info()["sysname"]
  if(myOS == "Windows")
    key_esc = gsub("\\\\", "\\\\\\\\", key)
    
  paste("|", key_esc, "|", sep="")
}

h2o.__func <- function(fname, x, type) {
  if(ncol(x) != 1) stop("Can only operate on single column vectors")
  expr = paste(fname, "(", h2o.__escape(x@key), ")", sep="")
  res = h2o.__exec(x@h2o, expr)
  res = h2o.__remoteSend(x@h2o, h2o.__PAGE_INSPECT, key=res)
  
  if(type == "Number")
    as.numeric(res$rows[[1]]$'0')
  else if(type == "Vector")
    new("H2OParsedData", h2o=x@h2o, key=res$key)
  else res
}

# Check if key_env$key exists in H2O and remove if it does
# h2o.__finalizer <- function(key_env) {
#   if("h2o" %in% ls(key_env) && "key" %in% ls(key_env) && class(key_env$h2o) == "H2OClient" && class(key_env$key) == "character" && key_env$key != "") {
#     res = h2o.__remoteSend(key_env$h2o, h2o.__PAGE_VIEWALL, filter=key_env$key)
#     if(length(res$keys) != 0)
#       h2o.__remoteSend(key_env$h2o, h2o.__PAGE_REMOVE, key=key_env$key)
#   }
# }

h2o.__version <- function(client) {
  res = h2o.__remoteSend(client, h2o.__PAGE_CLOUD)
  res$version
}

h2o.__getFamily <- function(family, link, tweedie.var.p = 0, tweedie.link.p = 1-tweedie.var.p) {
  if(family == "tweedie")
    return(tweedie(var.power = tweedie.var.p, link.power = tweedie.link.p))
  
  if(missing(link)) {
    switch(family,
           gaussian = gaussian(),
           binomial = binomial(),
           poisson = poisson(),
           gamma = gamma())
  } else {
    switch(family,
           gaussian = gaussian(link),
           binomial = binomial(link),
           poisson = poisson(link),
           gamma = gamma(link))
  }
}

#------------------------------------ FluidVecs -----------------------------------------#
h2o.__exec2 <- function(client, expr) {
  destKey = paste(TEMP_KEY, ".", pkg.env$temp_count, sep="")
  pkg.env$temp_count = (pkg.env$temp_count + 1) %% RESULT_MAX
  h2o.__exec2_dest_key(client, expr, destKey)
  # h2o.__exec2_dest_key(client, expr, TEMP_KEY)
}

h2o.__exec2_dest_key <- function(client, expr, destKey) {
  type = tryCatch({ typeof(expr) }, error = function(e) { "expr" })
  if (type != "character")
    expr = deparse(substitute(expr))
  expr = paste(destKey, "=", expr)
  res = h2o.__remoteSend(client, h2o.__PAGE_EXEC2, str=expr)
  if(!is.null(res$response$status) && res$response$status == "error") stop("H2O returned an error!")
  res$dest_key = destKey
  return(res)
}

h2o.__unop2 <- function(op, x) {
  expr = paste(op, "(", x@key, ")")
  res = h2o.__exec2(x@h2o, expr)
  if(res$num_rows == 0 && res$num_cols == 0)   # TODO: If logical operator, need to indicate
    return(res$scalar)
  if(op %in% LOGICAL_OPERATORS)
    new("H2OLogicalData2", h2o=x@h2o, key=res$dest_key)
  else
    new("H2OParsedData2", h2o=x@h2o, key=res$dest_key)
}

h2o.__binop2 <- function(op, x, y) {
  # if(!((ncol(x) == 1 || class(x) == "numeric") && (ncol(y) == 1 || class(y) == "numeric")))
  #  stop("Can only operate on single column vectors")
  LHS = ifelse(class(x) == "H2OParsedData2" || class(x) == "H2OLogicalData2", x@key, x)
  RHS = ifelse(class(y) == "H2OParsedData2" || class(y) == "H2OLogicalData2", y@key, y)
  expr = paste(LHS, op, RHS)
  if(class(x) == "H2OParsedData2" || class(x) == "H2OLogicalData2") myClient = x@h2o
  else myClient = y@h2o
  res = h2o.__exec2(myClient, expr)

  if(res$num_rows == 0 && res$num_cols == 0)   # TODO: If logical operator, need to indicate
    return(res$scalar)
  if(op %in% LOGICAL_OPERATORS)
    new("H2OLogicalData2", h2o=myClient, key=res$dest_key)
  else
    new("H2OParsedData2", h2o=myClient, key=res$dest_key)
}