package org.byu.cs452.persistence;

import java.sql.ResultSet;
import java.sql.SQLException;

/**
 * @author blissrj
 */
@SuppressWarnings("unused")
public class Student {
  public static final String ID = "id";
  public static final String NAME = "name";
  public static final String DEPARTMENT_NAME = "dept_name";
  public static final String TOTAL_CREDITS = "tot_cred";
  public static final String TABLE_NAME = "student";

  private String id;
  private String name;
  private String departmentName;
  private int totalCredits;


  public String getId() {
    return id;
  }

  public void setId(String id) {
    this.id = id;
  }

  public String getName() {
    return name;
  }

  public void setName(String name) {
    this.name = name;
  }

  public String getDepartmentName() {
    return departmentName;
  }

  public void setDepartmentName(String departmentName) {
    this.departmentName = departmentName;
  }

  public int getTotalCredits() {
    return totalCredits;
  }

  public void setTotalCredits(int totalCredits) {
    this.totalCredits = totalCredits;
  }

  public static String tableName() {
    return TABLE_NAME;
  }

  public static String columnNames() {
    return String.join(",", ID, NAME, DEPARTMENT_NAME, TOTAL_CREDITS);
  }

  public static Student getInstance(ResultSet resultSet) {
    Student student = new Student();
    try {
      student.setId(resultSet.getString(ID));
      student.setName(resultSet.getString(NAME));
      student.setDepartmentName(resultSet.getString(DEPARTMENT_NAME));
      student.setTotalCredits(resultSet.getInt(TOTAL_CREDITS));
      return student;
    }
    catch (SQLException e) {
      throw new RuntimeException("Failed to populate Student from ResultSet", e);
    }
  }
}
