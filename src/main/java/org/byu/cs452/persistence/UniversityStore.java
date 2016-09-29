package org.byu.cs452.persistence;


import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.util.ArrayList;
import java.util.List;

/**
 * @author blissrj
 */
public class UniversityStore {
  private ConnectionFactory connectionFactory;

  public UniversityStore() {
    this.connectionFactory = new PostgreSQLPooledConnectionFactory("localhost", "CS452", "university", 10, "postgres", "postgres");
  }

  /**
   * Read student by  id
   * @param id Id of student to be returned
   * @return student specified by id
   */
  public Student readStudent(String id) {
    Connection conn = connectionFactory.getConnection();
    try {
      String sqlString = String.format("SELECT %1$s FROM %2$s WHERE id=?", Student.columnNames(), Student.tableName());
      PreparedStatement statement = conn.prepareStatement(sqlString);
      statement.setString(1, id);
      ResultSet resultSet = statement.executeQuery();
      if (!resultSet.next()) {
        throw new NotFoundException("No record found for student: " + id);
      }
      return Student.getInstance(resultSet);
    }
    catch (SQLException e) {
      throw new RuntimeException("Unexpected database exception attempting to read student id: " + id, e);
    }
    finally {
      if (conn != null) {
        try {conn.close();} catch (SQLException ignore) {
        }
      }
    }
  }

  /**
   * Read all students
   * @return List of students
   */
  public List<Student> readStudents() {
    List<Student> students = new ArrayList<>();
    Connection conn = connectionFactory.getConnection();
    try {
      String sqlString = String.format("SELECT %1$s FROM %2$s", Student.columnNames(), Student.tableName());
      PreparedStatement statement = conn.prepareStatement(sqlString);
      ResultSet resultSet = statement.executeQuery();
      while (resultSet.next()) {
        students.add(Student.getInstance(resultSet));
      }
      return students;
    }
    catch (SQLException e) {
      throw new RuntimeException("Unexpected database exception attempting to read students", e);
    }
  }
}
