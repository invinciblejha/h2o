import unittest, time, sys
sys.path.extend(['.','..','py'])
import h2o_cmd, h2o, h2o_hosts, h2o_import as h2i

class Basic(unittest.TestCase):
    def tearDown(self):
        h2o.check_sandbox_for_errors()

    @classmethod
    def setUpClass(cls):
        h2o_hosts.build_cloud_with_hosts(use_hdfs=False)

    @classmethod
    def tearDownClass(cls):
        h2o.tear_down_cloud()

    def test_A_Basic(self):
        for n in h2o.nodes:
            h2o.verboseprint("cloud check for:", n)            
            c = n.get_cloud()
            self.assertEqual(c['cloud_size'], len(h2o.nodes), 'inconsistent cloud size')

    def test_B_RF_iris2(self):
        parseResult = h2i.import_parse(bucket='smalldata', path='iris/iris2.csv', schema='put')
        h2o_cmd.runRF(parseResult=parseResult, trees=6, model_key="iris2", timeoutSecs=10, retryDelaySecs=1)

    def test_C_RF_poker100(self):
        # RFview consumes cycles. Only retry once a second, to avoid slowing things down
        parseResult = h2i.import_parse(bucket='smalldata', path='poker/poker100', schema='put')
        h2o_cmd.runRF(parseResult=parseResult, trees=6, model_key="poker100", timeoutSecs=10, retryDelaySecs=1)

    def test_D_GenParity1(self):
        # Create a directory for the created dataset files. ok if already exists
        SYNDATASETS_DIR = h2o.make_syn_dir()
        # always match the run below!
        print "\nGenerating some large row count parity datasets in", SYNDATASETS_DIR,
        print "\nmay be a minute.........."
        for x in xrange (161,240,20):
            # more rows!
            y = 10000 * x
            # Have to split the string out to list for pipe
            shCmdString = "perl " + h2o.find_file("syn_scripts/parity.pl") + " 128 4 "+ str(y) + " quad " + SYNDATASETS_DIR
            # FIX! as long as we're doing a couple, you'd think we wouldn't have to 
            # wait for the last one to be gen'ed here before we start the first below.
            # large row counts. need more time
            h2o.spawn_cmd_and_wait('parity.pl', shCmdString.split(),timeout=90)
            # the algorithm for creating the path and filename is hardwired in parity.pl..i.e
            csvFilename = "parity_128_4_" + str(x) + "_quad.data"  
            sys.stdout.write('.')
            sys.stdout.flush()
        print "\nDatasets generated. Using."

        # always match the gen above!
        # Let's try it twice!
        for trials in xrange(1,7):
            # prime
            trees = 4057
            trees = 6

            for x in xrange (161,240,20):
                y = 10000 * x
                print "\nTrial:", trials, ", y:", y

                csvFilename = "parity_128_4_" + str(y) + "_quad.data"  
                csvPathname = SYNDATASETS_DIR + '/' + csvFilename
                # FIX! TBD do we always have to kick off the run from node 0?
                # random guess about length of time, varying with more hosts/nodes?
                timeoutSecs = 30 + trees*(len(h2o.nodes))

                # change the model name each iteration, so they stay in h2o
                model_key = csvFilename + "_" + str(trials)
                parseResult = h2i.import_parse(path=csvPathname, schema='put')
                h2o_cmd.runRF(parseResult=parseResult, 
                    trees=trees, model_key=model_key, timeoutSecs=timeoutSecs, retryDelaySecs=1)

if __name__ == '__main__':
    h2o.unit_main()

