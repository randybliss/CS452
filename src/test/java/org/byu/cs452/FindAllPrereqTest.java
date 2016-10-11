package org.byu.cs452;

import org.byu.cs452.examples.FindAllPrereq;
import org.testng.annotations.Test;

/**
 * @author blissrj
 */
public class FindAllPrereqTest {
  @Test(enabled = false)
  public void testFindAllPrereqTest() {
    FindAllPrereq.findPrereqs(new String[]{"postgres", "postgres", "CS-611"});
  }

  @Test(enabled = false)
  public void testLoadByuCsPrereqs() {
    FindAllPrereq.loadByuPrereqs(new String[] {"postgres", "postgres", "/Users/blissrj/CS452/byu-cs-courses.csv"});
  }
}
