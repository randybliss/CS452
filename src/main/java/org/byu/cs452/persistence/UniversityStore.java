package org.byu.cs452.persistence;


import org.springframework.beans.factory.annotation.Autowired;

import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;

/**
 * @author blissrj
 */
public class UniversityStore {
  private ConnectionFactory connectionFactory;

  public UniversityStore() {
    this.connectionFactory = new PostgreSQLPooledConnectionFactory("localhost", "CS452", "university", 10, "postgres", "postgres");
  }

  public Student getStudent(String id) {
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
      try {
        conn.close();
      }
      catch (SQLException e) {
        //noinspection ThrowFromFinallyBlock
        throw new RuntimeException("Unexpected exception attempting to close database connection: " + conn, e);
      }
    }
  }
}
