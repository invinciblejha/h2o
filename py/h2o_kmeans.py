import h2o_cmd, h2o
import re, math, random

def pickRandKMeansParams(paramDict, params):
    randomGroupSize = random.randint(1,len(paramDict))
    for i in range(randomGroupSize):
        randomKey = random.choice(paramDict.keys())
        randomV = paramDict[randomKey]
        randomValue = random.choice(randomV)
        params[randomKey] = randomValue

def simpleCheckKMeans(self, kmeans, **kwargs):
    ### print h2o.dump_json(kmeans)
    warnings = None
    if 'warnings' in kmeans:
        warnings = kmeans['warnings']
        # catch the 'Failed to converge" for now
        x = re.compile("[Ff]ailed")
        for w in warnings:
            print "\nwarning:", w
            if re.search(x,w): raise Exception(w)

    # Check other things in the json response dictionary 'kmeans' here
    destination_key = kmeans["destination_key"]
    kmeansResult = h2o_cmd.runInspect(key=destination_key)
    clusters = kmeansResult["KMeansModel"]["clusters"]
    for i,c in enumerate(clusters):
        for n in c:
            if math.isnan(n):
                raise Exception("center", i, "has NaN:", n, "center:", c)

    # shouldn't have any errors
    h2o.check_sandbox_for_errors()

    return warnings


def bigCheckResults(self, kmeans, csvPathname, parseResult, applyDestinationKey, **kwargs):
    simpleCheckKMeans(self, kmeans, **kwargs)
    model_key = kmeans['destination_key']
    kmeansResult = h2o_cmd.runInspect(key=model_key)
    centers = kmeansResult['KMeansModel']['clusters']

    kmeansApplyResult = h2o.nodes[0].kmeans_apply(
        data_key=parseResult['destination_key'], model_key=model_key,
        destination_key=applyDestinationKey)
    inspect = h2o_cmd.runInspect(None, applyDestinationKey)
    h2o_cmd.infoFromInspect(inspect, csvPathname)

    # this was failing
    summaryResult = h2o_cmd.runSummary(key=applyDestinationKey)
    h2o_cmd.infoFromSummary(summaryResult, noPrint=False)

    kmeansScoreResult = h2o.nodes[0].kmeans_score(
        key=parseResult['destination_key'], model_key=model_key)
    score = kmeansScoreResult['score']
    rows_per_cluster = score['rows_per_cluster']
    sqr_error_per_cluster = score['sqr_error_per_cluster']

    tupleResultList = []
    for i,c in enumerate(centers):
        print "\ncenters["+str(i)+"]: ", centers[i]
        print "rows_per_cluster["+str(i)+"]: ", rows_per_cluster[i]
        print "sqr_error_per_cluster["+str(i)+"]: ", sqr_error_per_cluster[i]
        tupleResultList.append( (centers[i], rows_per_cluster[i], sqr_error_per_cluster[i]) )

    return (centers, tupleResultList)


# list of tuples: center, rows, sqr_error
# expected = [ # tupleResultList is returned by bigCheckResults like this
#       ([-2.2824436059344264, -0.9572469619836067], 61, 71.04484889371177),
#       ([0.04072444664179102, 1.738305108029851], 67, 118.83608173427331),
#       ([2.7300104405999996, -1.16148755108], 50, 68.67496427685141)
# ]
# delta is a tuple of multipliers against the tupleResult for abs delta
# allowedDelta = (0.01, 0.1, 0.01)
def compareResultsToExpected(self, tupleResultList, expected=None, allowedDelta=None, allowError=False, trial=0):
    # sort the tuple list by center for the comparison. (this will be visible to the caller?)
    from operator import itemgetter
    tupleResultList.sort(key=itemgetter(0))

    if expected is not None:
        # sort expected, just in case, for the comparison
        expected.sort(key=itemgetter(0))
        print "\nTrial #%d Expected:" % trial
        for e in expected:
            print e

    # now compare to expected, with some delta allowed
    print "\nTrial #%d Actual:" % trial
    for t in tupleResultList:
        print t, "," # so can cut and paste and put results in an expected = [..] list

    if expected is not None and not allowError: # allowedDelta must exist if expected exists
        for i, (expCenter, expRows, expError)  in enumerate(expected):
            (actCenter, actRows, actError) = tupleResultList[i]

            for (a,b) in zip(expCenter, actCenter): # compare list of floats
                absAllowedDelta = allowedDelta[0] * a
                self.assertAlmostEqual(a, b, delta=allowedDelta,
                    msg="Trial %d Center expected: %s actual: %s delta > %s" % (trial, expCenter, actCenter, absAllowedDelta))

            absAllowedDelta = allowedDelta[1] * expRows
            self.assertAlmostEqual(expRows, actRows, delta=absAllowedDelta,
                msg="Trial %d Rows expected: %s actual: %s delta > %s" % (trial, expRows, actRows, absAllowedDelta))

            if expError is not None: # don't always check this
                absAllowedDelta = allowedDelta[2] * expError
                self.assertAlmostEqual(expError, actError, delta=absAllowedDelta,
                    msg="Trial %d Error expected: %s actual: %s delta > %s" % (trial, expError, actError, absAllowedDelta))


# compare this clusters to last one. since the files are concatenations, 
# the results should be similar? 10% of first is allowed delta
def compareToFirstKMeans(self, clusters, firstclusters):
    # clusters could be a list or not. if a list, don't want to create list of that list
    # so use extend on an empty list. covers all cases?
    if type(clusters) is list:
        kList  = clusters
        firstkList = firstclusters
    elif type(clusters) is dict:
        raise Exception("compareToFirstGLm: Not expecting dict for " + key)
    else:
        kList  = [clusters]
        firstkList = [firstclusters]

    for k, firstk in zip(kList, firstkList):
        # delta must be a positive number?
        delta = .1 * abs(float(firstk))
        msg = "Too large a delta (>" + str(delta) + ") comparing current and first clusters: " + \
            str(float(k)) + ", " + str(float(firstk))
        self.assertAlmostEqual(float(k), float(firstk), delta=delta, msg=msg)
        self.assertGreaterEqual(abs(float(k)), 0.0, str(k) + " abs not >= 0.0 in current")

