package org.byu.cs452.examples;

import org.testng.annotations.Test;

/**
 * @author blissrj
 */
public class FindAllAncestorsTest {
  @Test
  public void testFindAllAncestors() {
    FindAllAncestors.findAncestors(new String[]{"postgres", "postgres", "LFDN-3X3"});
  }

  @Test(enabled = false)
  public void testLoadPersons() {
    FindAllAncestors.loadAncestorPersons(new String[] {"postgres", "postgres", "/Users/blissrj/CS452/id-gender-list.csv"});
  }

  @Test(enabled = false)
  public void testLoadPCRelationships() {
    FindAllAncestors.loadAncestorRelationships(new String[] {"postgres", "postgres", "/Users/blissrj/CS452/parent-child-list.csv"});
  }
}
