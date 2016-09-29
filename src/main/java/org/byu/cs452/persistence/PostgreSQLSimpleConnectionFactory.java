package org.byu.cs452.persistence;

import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.SQLException;

/**
 * @author blissrj
 */
public class PostgreSQLSimpleConnectionFactory implements ConnectionFactory{
  private static final String POSTGRESQL_DRIVER_NAME = "org.postgresql.Driver";
  private String schema;
  private String url;
  private String userName;
  private String password;

  public PostgreSQLSimpleConnectionFactory(String host, String database, String schema, String userName, String password) {
    this.url = String.format("jdbc:postgresql://%s:5432/%s", host, database);
    this.schema = schema;
    this.userName = userName;
    this.password = password;
    try {
      Class.forName(POSTGRESQL_DRIVER_NAME);
    }
    catch (ClassNotFoundException e) {
      e.printStackTrace();
    }
  }

  @Override
  public Connection getConnection() {
    try {
      Connection conn = DriverManager.getConnection(url, userName, password);
      conn.setSchema(schema);
      return conn;
    }
    catch (SQLException e) {
      throw new RuntimeException("Failed to get connection");
    }
  }
}
