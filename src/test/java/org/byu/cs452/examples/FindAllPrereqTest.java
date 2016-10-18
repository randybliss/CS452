package org.byu.cs452.examples;

import org.testng.annotations.Test;

/**
 * @author blissrj
 */
public class FindAllPrereqTest {
  
  @Test(enabled = false)
  public void testFindAllPrereq() {
    FindAllPrereq.findPrereqs(new String[]{"postgres", "postgres", "CS-611"});
  }

  @Test(enabled = false)
  public void testLoadByuCsPrereqs() {
    FindAllPrereq.loadByuPrereqs(new String[] {"postgres", "postgres", "/Users/blissrj/CS452/byu-cs-courses.csv"});
  }
}
