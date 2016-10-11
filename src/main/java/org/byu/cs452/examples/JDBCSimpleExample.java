package org.byu.cs452.examples;

import org.byu.cs452.persistence.NotFoundException;

import java.sql.*;

/**
 * @author blissrj
 */
public class JDBCSimpleExample {
  public static void demo() {
    Connection connection = null;
    try {
      // Register driver, get connection, set schema (search_path)
      Class.forName("org.postgresql.Driver");
      connection = DriverManager.getConnection("jdbc:postgresql://localhost:5432/CS452", "postgres", "postgres");
      connection.setSchema("university");

      // Create and execute statement to read id,name,dept_name,tot_cred for student with id '12345'
      Statement statement = connection.createStatement();
      ResultSet resultSet = statement.executeQuery("SELECT id,name,dept_name,tot_cred FROM student where id='12345'");

      // When reading for a single row, if resultSet.next() returns false means nothing in result set i.e. record not found
      if (!resultSet.next()) {
        throw new NotFoundException("row not found for id: 12345");
      }

      // Get column values from returned row into local variables
      String id = resultSet.getString("id");
      String name = resultSet.getString("name");
      String deptName = resultSet.getString("dept_name");
      int totCred = resultSet.getInt("tot_cred");

      // Format and output attributes (column values) for student with id '12345'
      String output = String.format("Student data for id: %s, name: %s, department: %s, total credits: %4d", id, name, deptName, totCred);
      System.out.println();
      System.out.println(output);
    }
    catch (ClassNotFoundException | SQLException e) {
      e.printStackTrace();
    }
    // Be a good citizen and close your connection - or risk crashing with too many open connections - your choice
    finally {
      if (connection != null) {
        try {connection.close();}catch(SQLException ignore){}
      }
    }
  }
}
