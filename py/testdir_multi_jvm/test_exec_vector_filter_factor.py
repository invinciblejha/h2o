import unittest
import random, sys, time, os
sys.path.extend(['.','..','py'])
import h2o, h2o_cmd, h2o_hosts, h2o_browse as h2b, h2o_import as h2i, h2o_exec as h2e

zeroList = [
        'Result0 = 0',
        'Result1 = 0',
]

exprList = [
        'Result<n> = <keyX>[<col1>] + <keyX>[<col2>] + <keyX>[2]' ,

# FIX! bug due to missing value in col 54
#        ['Result<n> = factor(<keyX>[54])',
        'Result<n> = factor(<keyX>[53])',
        'Result<n> = factor(<keyX>[28])',
        'Result<n> = randomBitVector(<row>,1,12345)',
        'Result<n> = randomBitVector(<row>,0,23456)',
# FIX! bugs in all of these?
#        'Result<n> = randomFilter(<keyX>[<col1>],<row>)',
#        'Result<n> = randomFilter(<keyX>,<row>)',
#        'Result<n> = randomFilter(<keyX>,3)',

        'Result<n> = <keyX>[<col1>]',
        'Result<n> = min(<keyX>[<col1>])',
        'Result<n> = max(<keyX>[<col1>]) + Result<n-1>',
        'Result<n> = sum(<keyX>[<col1>]) + Result.hex',
    ]

class Basic(unittest.TestCase):
    def tearDown(self):
        h2o.check_sandbox_for_errors()

    @classmethod
    def setUpClass(cls):
        global SEED, localhost
        SEED = h2o.setup_random_seed()
        localhost = h2o.decide_if_localhost()
        if (localhost):
            # h2o.build_cloud(3,java_heap_GB=4)
            h2o.build_cloud(1,java_heap_GB=4)
        else:
            h2o_hosts.build_cloud_with_hosts()

    @classmethod
    def tearDownClass(cls):
        # wait while I inspect things
        # time.sleep(1500)
        h2o.tear_down_cloud()

    def test_vector_filter_factor(self):
        # make the timeout variable per dataset. it can be 10 secs for covtype 20x (col key creation)
        # so probably 10x that for covtype200
        if localhost:
            maxTrials = 200
            csvFilenameAll = [
                ("covtype.data", "cA", 5),
                ("covtype.data", "cB", 5),
            ]
        else:
            maxTrials = 20
            csvFilenameAll = [
                ("covtype.data", "cA", 5),
                ("covtype20x.data", "cC", 50),
            ]

        ### csvFilenameList = random.sample(csvFilenameAll,1)
        csvFilenameList = csvFilenameAll
        lenNodes = len(h2o.nodes)
        importFolderPath = "standard"

        for (csvFilename, hex_key, timeoutSecs) in csvFilenameList:
            # have to import each time, because h2o deletes the source file after parse
            csvPathname = importFolderPath + "/" + csvFilename
            # creates csvFilename.hex from file in importFolder dir 
            parseResult = h2i.import_parse(bucket='home-0xdiag-datasets', path=csvPathname, 
                hex_key=hex_key, timeoutSecs=2000)
            print csvFilename, 'parse time:', parseResult['response']['time']
            print "Parse result['destination_key']:", parseResult['destination_key']
            inspect = h2o_cmd.runInspect(None, parseResult['destination_key'])

            print "\n" + csvFilename
            h2e.exec_zero_list(zeroList)
            # does n+1 so use maxCol 53
            h2e.exec_expr_list_rand(lenNodes, exprList, hex_key, 
                maxCol=53, maxRow=400000, maxTrials=maxTrials, timeoutSecs=timeoutSecs)


if __name__ == '__main__':
    h2o.unit_main()
