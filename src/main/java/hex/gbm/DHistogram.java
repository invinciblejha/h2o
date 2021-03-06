package hex.gbm;

import water.*;
import water.fvec.Frame;
import water.fvec.Vec;
import water.util.Log;

/**
   A DHistogram, computed in parallel over a Vec.
   <p>
   A {@code DHistogram} bins (by default into {@value BINS} bins)
   every value added to it, and computes a the min, max, and either
   class distribution or mean & variance for each bin.  {@code
   DHistogram}s are initialized with a min, max and number-of-elements
   to be added (all of which are generally available from a Vec).
   Bins normally run from min to max in uniform sizes, but if the
   {@code DHistogram} can determine that fewer bins are needed
   (e.g. boolean columns run from 0 to 1, but only ever take on 2
   values, so only 2 bins are needed), then fewer bins are used.
   </p><p>
   If we are successively splitting rows (e.g. in a decision tree), then a
   fresh {@code DHistogram} for each split will dynamically re-bin the data.
   Each successive split then, will logarithmically divide the data.  At the
   first split, outliers will end up in their own bins - but perhaps some
   central bins may be very full.  At the next split(s), the full bins will get
   split, and again until (with a log number of splits) each bin holds roughly
   the same amount of data.
   </p>
   @author Cliff Click
*/
public class DHistogram<T extends DHistogram> extends Iced {
  transient final String _name; // Column name, for pretty-printing
  final byte _isInt;            // 0=>floats, 1,2=>Column only holds integers, 2=>Enum
  float _min, _max;             // Ends of binning
  public DHistogram( String name, byte isInt, float min, float max ) {
    _name = name;
    _isInt = isInt;
    _min = min;
    _max = max;
  }
  public DHistogram( String name, byte isInt ) {
    this(name,isInt,Float.MAX_VALUE,-Float.MAX_VALUE);
  }

  // All these functions are overridden in subclasses

  // Return a copy that is ready to be updated and/or collect binning info.
  public DHistogram smallCopy( ) { return (DHistogram)clone(); }

  public DHistogram bigCopy( ) {
    throw H2O.unimpl();
  }

  // Add 1 count to bin specified by float.
  // For non-tracking columns, just min/max
  void incr( float d ) {
    if( d < _min ) _min = d;
    if( d > _max ) _max = d;
  }

  void add( T h ) {
    if( h._min < _min ) _min = h._min;
    if( h._max > _max ) _max = h._max;
  }

  // Number of active bins
  public int nbins() { return 1; }
  // Number of rows in this bin.
  public long bins(int i) { return 0; }
  // Smallest value in bin i
  public float mins(int i) { return _min; }
  // Largest value in bin i
  public float maxs(int i) { return _max; }
  public DTree.Split scoreMSE( int col ) { return null; }
  // Do not ask for 'mean' from a non-scoring histogram
  public double mean( int bin ) { return Double.NaN; }
  // Do not ask for 'var' from a non-scoring histogram
  public double var( int bin ) { return Double.NaN; }

  // Nothing to tighten
  public void tightenMinMax() { }
  public void fini() { }
  // Getters
  public final double min() { return _min; }
  public final double max() { return _max; }
  public final String name() { return _name; }

  protected static int byteSize(byte  []bs) { return bs==null ? 0 : 20+bs.length<<0; }
  protected static int byteSize(short []ss) { return ss==null ? 0 : 20+ss.length<<1; }
  protected static int byteSize(float []fs) { return fs==null ? 0 : 20+fs.length<<2; }
  protected static int byteSize(int   []is) { return is==null ? 0 : 20+is.length<<2; }
  protected static int byteSize(long  []ls) { return ls==null ? 0 : 24+ls.length<<3; }
  protected static int byteSize(double[]fs) { return fs==null ? 0 : 24+fs.length<<3; }
  protected static int byteSize(Object[]ls) { return ls==null ? 0 : 24+ls.length<<3; }

  long byteSize() {
    return 16/*hdr*/+8/*name*/+(4+4)/*min+max*/+1/*isInt*/+7/*PAD*/;
  }
}
