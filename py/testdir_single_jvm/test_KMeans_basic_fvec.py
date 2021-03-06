import unittest, time, sys
sys.path.extend(['.','..','py'])
import h2o, h2o_cmd, h2o_kmeans, h2o_hosts, h2o_import as h2i, h2o_jobs

class Basic(unittest.TestCase):
    def tearDown(self):
        h2o.check_sandbox_for_errors()

    @classmethod
    def setUpClass(cls):
        global localhost
        localhost = h2o.decide_if_localhost()
        if (localhost):
            h2o.build_cloud(1)
        else:
            h2o_hosts.build_cloud_with_hosts(1)
        h2o.beta_features = True # fvec

    @classmethod
    def tearDownClass(cls):
        h2o.tear_down_cloud()

    def test_B_kmeans_benign(self):
        importFolderPath = "standard"
        csvFilename = "benign.csv"
        hex_key = "benign.hex"

        csvPathname = importFolderPath + "/" + csvFilename
        # FIX! hex_key isn't working with Parse2 ? parseResult['destination_key'] not right?
        parseResult = h2i.import_parse(bucket='home-0xdiag-datasets', path=csvPathname, hex_key=hex_key, header=1, 
            timeoutSecs=180, noPoll=h2o.beta_features, doSummary=False)

        if h2o.beta_features:
            h2o_jobs.pollWaitJobs(timeoutSecs=300, pollTimeoutSecs=300, retryDelaySecs=5)
            parseResult['destination_key'] = hex_key
        
        inspect = h2o_cmd.runInspect(None, parseResult['destination_key'])
        print "\nStarting", csvFilename

        expected = [
            ([24.538961038961038, 2.772727272727273, 46.89032467532467, 0.1266233766233766, 12.012142857142857, 1.0105194805194804, 1.5222727272727272, 22.26039690646432, 12.582467532467534, 0.5275062016635049, 2.9477601050634767, 162.52136363636365, 41.94558441558441, 1.661883116883117], 77, 46889.32010560476) ,
            ([25.587719298245613, 2.2719298245614037, 45.64035087719298, 0.35964912280701755, 13.026315789473685, 1.4298245614035088, 1.3070175438596492, 24.393307707470925, 13.333333333333334, 0.5244431302976542, 2.7326039818647745, 122.46491228070175, 40.973684210526315, 1.6754385964912282], 114, 64011.20272144667) ,
            ([30.833333333333332, 2.9166666666666665, 46.833333333333336, 0.0, 13.083333333333334, 1.4166666666666667, 1.5833333333333333, 24.298220973782772, 11.666666666666666, 0.37640449438202245, 3.404494382022472, 224.91666666666666, 39.75, 1.4166666666666667], 12, 13000.485226507595) ,

        ]
        # all are multipliers of expected tuple value
        allowedDelta = (0.01, 0.01, 0.01)

        # loop, to see if we get same centers
        for k in range(2, 6):
            kwargs = {'k': k, 'ignored_cols_by_name': None, 'destination_key': 'benign_k.hex',
                # reuse the same seed, to get deterministic results (otherwise sometimes fails
                'seed': 265211114317615310}

            # for fvec only?
            kwargs.update({'max_iter': 10})
            kmeans = h2o_cmd.runKMeans(parseResult=parseResult, timeoutSecs=5, noPoll=h2o.beta_features, **kwargs)

            if h2o.beta_features:
                h2o_jobs.pollWaitJobs(timeoutSecs=300, pollTimeoutSecs=300, retryDelaySecs=5)
                # hack..supposed to be there like va
                kmeans['destination_key'] = 'benign_k.hex'
            ## h2o.verboseprint("kmeans result:", h2o.dump_json(kmeans))
            modelView = h2o.nodes[0].kmeans_model_view(model='benign_k.hex')
            h2o.verboseprint("KMeans2ModelView:", h2o.dump_json(modelView))
            model = modelView['model']
            clusters = model['clusters']
            cluster_variances = model['cluster_variances']
            error = model['error']
            print "cluster_variances:", cluster_variances
            print "error:", error

            # make this fvec legal?
            ### (centers, tupleResultList) = h2o_kmeans.bigCheckResults(self, kmeans, csvPathname, parseResult, 'd', **kwargs)
            ### h2o_kmeans.compareResultsToExpected(self, tupleResultList, expected, allowedDelta, trial=trial)


    def test_C_kmeans_prostate(self):

        importFolderPath = "standard"
        csvFilename = "prostate.csv"
        hex_key = "prostate.hex"
        csvPathname = importFolderPath + "/" + csvFilename
        parseResult = h2i.import_parse(bucket='home-0xdiag-datasets', path=csvPathname, hex_key=hex_key, header=1, timeoutSecs=180)
        inspect = h2o_cmd.runInspect(None, parseResult['destination_key'])
        print "\nStarting", csvFilename

        # loop, to see if we get same centers
        expected = [
            ([55.63235294117647], 68, 667.8088235294117) ,
            ([63.93984962406015], 133, 611.5187969924812) ,
            ([71.55307262569832], 179, 1474.2458100558654) ,
        ]

        # all are multipliers of expected tuple value
        allowedDelta = (0.01, 0.01, 0.01)
        for k in range(2, 6):
            kwargs = {'k': k, 'initialization': 'Furthest', 'destination_key': 'prostate_k.hex',
                # reuse the same seed, to get deterministic results (otherwise sometimes fails
                'seed': 265211114317615310}

            # for fvec only?
            kwargs.update({'max_iter': 50})

            kmeans = h2o_cmd.runKMeans(parseResult=parseResult, timeoutSecs=5, noPoll=h2o.beta_features, **kwargs)
            if h2o.beta_features:
                h2o_jobs.pollWaitJobs(timeoutSecs=300, pollTimeoutSecs=300, retryDelaySecs=5)
                # hack..supposed to be there like va
                kmeans['destination_key'] = 'prostate_k.hex'
            # FIX! how do I get the kmeans result?
            ### print "kmeans result:", h2o.dump_json(kmeans)
            # can't do this
            # inspect = h2o_cmd.runInspect(key='prostate_k.hex')
            modelView = h2o.nodes[0].kmeans_model_view(model='prostate_k.hex')
            h2o.verboseprint("KMeans2ModelView:", h2o.dump_json(modelView))

            model = modelView['model']
            clusters = model['clusters']
            cluster_variances = model['cluster_variances']
            error = model['error']
            print "cluster_variances:", cluster_variances
            print "error:", error
            # variance of 0 might be legal with duplicated rows. wasn't able to remove the duplicate rows of NAs at 
            # bottom of benign.csv in ec2
            # for i,c in enumerate(cluster_variances):
            #    if c < 0.1:
            #        raise Exception("cluster_variance %s for cluster %s is too small. Doesn't make sense. Ladies and gentlemen, this is Chewbacca. Chewbacca is a Wookiee from the planet Kashyyyk. But Chewbacca lives on the planet Endor. Now think about it...that does not make sense!" % (c, i))
            

            # make this fvec legal?
            ### (centers, tupleResultList) = h2o_kmeans.bigCheckResults(self, kmeans, csvPathname, parseResult, 'd', **kwargs)

            ### h2o_kmeans.compareResultsToExpected(self, tupleResultList, expected, allowedDelta, trial=trial)



if __name__ == '__main__':
    h2o.unit_main()
