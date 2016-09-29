package org.byu.cs452.persistence;

import org.apache.commons.dbcp2.BasicDataSource;
import javax.sql.DataSource;
import java.sql.Connection;
import java.sql.SQLException;

/**
 * @author blissrj
 */
public class PostgreSQLPooledConnectionFactory implements ConnectionFactory{
  private static final String POSTGRESQL_DRIVER_NAME = "org.postgresql.Driver";

  private DataSource dataSource;
  private String schema;

  public PostgreSQLPooledConnectionFactory(String host, String database, String schema, int maxConnections, String userName, String password) {
    this.dataSource = initDataSource(host, database, maxConnections, userName, password);
    this.schema = schema;
  }

  @Override
  public Connection getConnection() {
    try {
      Connection conn = dataSource.getConnection();
      conn.setSchema(schema);
      return conn;
    }
    catch (SQLException e) {
      throw new RuntimeException("Failed to get connection");
    }
  }

  private DataSource initDataSource(String host, String database, int maxConnections, String userName, String password) {
    String url = String.format("jdbc:postgresql://%s:5432/%s", host, database);
    BasicDataSource dataSource = new BasicDataSource();
    dataSource.setDriverClassName(POSTGRESQL_DRIVER_NAME);
    dataSource.setUrl(url);
    dataSource.setUsername(userName);
    dataSource.setPassword(password);
    dataSource.setMaxTotal(maxConnections);
    return dataSource;
  }
}
