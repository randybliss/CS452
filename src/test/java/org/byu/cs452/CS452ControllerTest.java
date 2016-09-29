package org.byu.cs452;

import org.byu.cs452.persistence.Student;
import org.testng.annotations.Test;

import static org.testng.Assert.*;

/**
 * @author blissrj
 */
public class CS452ControllerTest {
  private CS452Controller cs452Controller = new CS452Controller();

  @Test
  void testGetStudent() {
    Student student = cs452Controller.getStudent("12345");
    assertTrue(student.getName().equals("Shankar"));
  }



}