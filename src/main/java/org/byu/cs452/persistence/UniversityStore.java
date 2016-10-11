package org.byu.cs452.persistence;


import java.math.BigDecimal;
import java.sql.*;
import java.util.ArrayList;
import java.util.List;

/**
 * @author blissrj
 */
public class UniversityStore {
  private ConnectionFactory connectionFactory;

  public UniversityStore() {
    this.connectionFactory = new PostgreSQLSimpleConnectionFactory("localhost", "CS452", "university", "postgres", "postgres");
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
        try {conn.close();} catch (SQLException ignore) {}
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
    finally {
      if (conn != null) {
        try {conn.close();} catch (SQLException ignore) {}
      }
    }
  }

  public DatabaseMetaData readDatabaseMetaData() {
    try (Connection conn = connectionFactory.getConnection()){
      return conn.getMetaData();
    }
    catch (SQLException e) {
      throw new RuntimeException("Unexpected database exception attempting to get metadata", e);
    }
  }

  public int registerStudent(String id, String courseId, String sectionId, String semester, int year) {
    try (Connection conn = connectionFactory.getConnection(); Statement stmt = conn.createStatement()){
      /*
       ** Start transaction
       */
      stmt.executeUpdate("begin");  //Start transaction

      // Get current number of students enrolled in desired course
      String sql = "SELECT count(*) FROM takes t WHERE t.course_id=? AND t.sec_id=? AND t.semester=? AND t.year=?";
      PreparedStatement ps = conn.prepareStatement(sql);
      ps.setString(1, courseId);
      ps.setString(2, sectionId);
      ps.setString(3, semester);
      ps.setInt(4, year);
      ResultSet rs = ps.executeQuery();
      long curEnrolled = (long) getScalar(rs);
      // Get classroom capacity for desired course
      sql = "SELECT capacity FROM classroom cr JOIN section s ON s.building = cr.building AND s.room_number = cr.room_number";
      sql = sql.concat(" WHERE s.course_id=? AND s.sec_id=? AND s.semester=? AND s.year=?");
      ps = conn.prepareStatement(sql);
      ps.setString(1, courseId);
      ps.setString(2, sectionId);
      ps.setString(3, semester);
      ps.setInt(4, year);
      rs = ps.executeQuery();
      BigDecimal bdCapacity = (BigDecimal) getScalar(rs);
      Long capacity = bdCapacity == null ? 0L : bdCapacity.longValue();
      // Determine if enrolled exceeds capacity
      if (curEnrolled >= capacity) {
        return 0;
      }
      // OK to go ahead and register student for course
      sql = "INSERT INTO takes (id, course_id, sec_id, semester, year) VALUES (?,?,?,?,?)";
      ps = conn.prepareStatement(sql);
      ps.setString(1, id);
      ps.setString(2, courseId);
      ps.setString(3, sectionId);
      ps.setString(4, semester);
      ps.setInt(5, year);
      ps.executeUpdate();
      /*
       ** Commit transaction
       */
      stmt.executeUpdate("commit");
      return 1;
    }
    catch (SQLException e) {
      throw new RuntimeException("Unexpected exception attempting to register student for course", e);
    }
  }

  public int createJsonStudent(String id, String name, String departmentName, int totalCredits) {
    JsonStudent student = new JsonStudent().setId(id).setName(name).setDepartmentName(departmentName).setTotalCredits(totalCredits);
    Connection conn = connectionFactory.getConnection();
    try {
      PreparedStatement statement = JsonStudent.getInsertStatement(conn, id, student.toNode().toString());
      return statement.executeUpdate();
    }
    catch (SQLException e) {
      throw new RuntimeException("Unexpected database exception attempting to insert JsonStudent", e);
    }
    finally {
      if (conn != null) {
        try {conn.close();} catch (SQLException ignore){};
      }
    }
  }

  public JsonStudent readJsonStudent(String id) {
    Connection conn = connectionFactory.getConnection();
    try {
      String sqlString = String.format("SELECT %1$s FROM %2$s WHERE id=?", JsonStudent.getColumnNames(), JsonStudent.getTableName());
      PreparedStatement statement = conn.prepareStatement(sqlString);
      statement.setString(1, id);
      ResultSet resultSet = statement.executeQuery();
      if (!resultSet.next()) {
        throw new NotFoundException("No record found for student: " + id);
      }
      return JsonStudent.getInstance(resultSet);
    }
    catch (SQLException e) {
      throw new RuntimeException("Unexpected database exception attempting to read Json Student id: " + id, e);
    }
    finally {
      if (conn != null) {
        try {conn.close();} catch (SQLException ignore){};
      }
    }
  }

  private Object getScalar(ResultSet resultSet) {
    try {
      if (!resultSet.next()) {
        return null;
      }
      return resultSet.getObject(1);
    }
    catch (SQLException e) {
      throw new RuntimeException("Unexpected database exception attempting to get scalar value from result set", e);
    }
  }
}
