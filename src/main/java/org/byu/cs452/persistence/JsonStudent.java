package org.byu.cs452.persistence;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.node.JsonNodeFactory;
import com.fasterxml.jackson.databind.node.ObjectNode;
import org.byu.cs452.CS452Application;

import java.io.IOException;
import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;

/**
 * @author blissrj
 */
public class JsonStudent {
  public static final String ID_TAG = "id";
  public static final String NAME_TAG = "name";
  public static final String DEPARTMENT_NAME_TAG = "dept_name";
  public static final String TOTAL_CREDITS_TAG = "tot_cred";

  public static final String ID_COLUMN_NAME = "id";
  public static final String CONTENT_COLUMN_NAME = "content";

  public static final String TABLE_NAME = "JsonStudent";

  private ObjectNode node;

  public JsonStudent() {
    this.node = JsonNodeFactory.instance.objectNode();
  }

  public String getId() {
    return node.path(ID_TAG).asText();
  }

  public JsonStudent setId(String id) {
    node.put(ID_TAG, id);
    return this;
  }

  public String getName() {
    return node.path(NAME_TAG).asText();
  }

  public JsonStudent setName(String name) {
    node.put(NAME_TAG, name);
    return this;
  }

  public String getDepartmentName() {
    return node.path(DEPARTMENT_NAME_TAG).asText();
  }

  public JsonStudent setDepartmentName(String departmentName) {
    node.put(DEPARTMENT_NAME_TAG, departmentName);
    return this;
  }

  public int getTotalCredits() {
    return node.path(TOTAL_CREDITS_TAG).asInt();
  }

  public JsonStudent setTotalCredits(int totalCredits) {
    node.put(TOTAL_CREDITS_TAG, totalCredits);
    return this;
  }

  public JsonNode toNode() {
    return node;
  }

  public static PreparedStatement getInsertStatement(Connection conn, String id, String content) {
    String sqlString = String.format("INSERT into %1$s (%2$s) values (?,?)", TABLE_NAME, getColumnNames());
    try {
      PreparedStatement statement = conn.prepareStatement(sqlString);
      statement.setString(1, id);
      statement.setString(2, content);
      return statement;
    }
    catch (SQLException e) {
      throw new RuntimeException("Failed to prepare SQL insert statement", e);
    }

  }

  public static String getColumnNames() {
    return String.join(",",ID_COLUMN_NAME,CONTENT_COLUMN_NAME);
  }

  public static String getTableName() {
    return TABLE_NAME;
  }

  public static JsonStudent getInstance(ResultSet resultSet) {
    try {
      JsonStudent student = new JsonStudent();
      student.node = (ObjectNode) CS452Application.getObjectMapper().readTree(resultSet.getString(2));
      return student;
    }
    catch (IOException e) {
      throw new RuntimeException("Unexpected exception attempting to parse JSON text", e);
    }
    catch (SQLException e) {
      throw new RuntimeException("Unexpected database exception extracting data from result set", e);
    }
  }
}
