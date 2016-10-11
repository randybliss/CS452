package org.byu.cs452.examples;

import java.io.*;
import java.sql.*;

public class FindAllPrereq {

  public static void loadByuPrereqs(String[] args) {
    new FindAllPrereq().load(args);
  }

  public static void findPrereqs(String[] args) {
    new FindAllPrereq().run(args);
  }

  private static final String DRIVER_NAME = "org.postgresql.Driver";
  private static final String CONNECT_STRING = "jdbc:postgresql://127.0.0.1:5432/CS452";

  private static Statement stmt = null;
  private static ResultSet rs = null;
  //
  // PreparedStatement instances
  //
  private static PreparedStatement pstmtInitItrTable = null;
  private static PreparedStatement pstmtInsertIntoResTable = null;
  private static PreparedStatement pstmtInsertIntoTmpTable = null;
  private static PreparedStatement pstmtDeleteFromItrTable = null;
  private static PreparedStatement pstmtInsertIntoItrTable = null;
  private static PreparedStatement pstmtDeleteFromTmpTable = null;
  private static PreparedStatement pstmtSelectFromResTable = null;
//  private static PreparedStatement pstmtSelectCountFromResTable = null;

  private void run(String[] args) {
    Connection con = null;

    final String username = args[0];      // username
    final String password = args[1];      // password
    final String seedCourseId = args[2];  // course id to get prerequisites for

    try {
      //
      // load driver class object
      //
      Class.forName(DRIVER_NAME);

      //
      // create a connection (session) to the database
      //    connection string = "jdbc:progresql:<database URL:port number>/<database name>"
      //
      con = DriverManager.getConnection(CONNECT_STRING, username, password);
      if (null == con) {
        System.out.println("failed to connect");
        return;
      }
      con.setSchema("byu_prereq");

      //
      // SQL strings
      //
      final String SQL_CREATE_RES_TABLE =  // accumulates prerequisites
          "create temporary table res_table("
              + "    course_id varchar(10) unique);";

      final String SQL_CREATE_ITR_TABLE =  // holds prerequisites for current iteration
          "create temporary table itr_table("
              + "    like res_table including all);";

      final String SQL_CREATE_TMP_TABLE =  // temporarily holds iteration prerequisites
          "create temporary table tmp_table("
              + "    like res_table including all);";


      final String SQL_INIT_ITR_TABLE =  // initializes the iteration table with first set of prereqs
          "insert into itr_table"
              + "    select prereq_id "
              + "    from byu_cs_course "
              + "    where course_id = ?;";

      final String SQL_INSERT_INTO_RES_TABLE =   // accumulates iteration prereqs
          "insert into res_table "
              + "    select course_id "
              + "    from itr_table;";

      final String SQL_DELETE_FROM_TMP_TABLE = "delete from tmp_table;";

      final String SQL_INSERT_INTO_TMP_TABLE =   // finds next set of prereqs
          "insert into tmp_table "
              + "    (select C.prereq_id "
              + "     from itr_table I, byu_cs_course C "
              + "     where I.course_id = C.course_id "
              + "           and C.prereq_id is not null"
              + "    )"
              + "    except "   // exclude prereqs already accumulated, set operation eliminates duplications
              + "   (select course_id "
              + "    from res_table"
              + "   );";

      final String SQL_DELETE_FROM_ITR_TABLE = "delete from itr_table;";

      final String SQL_INSERT_INTO_ITR_TABLE = // copies from temporary table into iteration table
          "insert into itr_table "
              + "    select course_id "
              + "    from tmp_table;";

      final String SQL_SELECT_FROM_RES_TABLE = "select * from res_table;";
      final String SQL_SELECT_COUNT_FROM_RES_TABLE = "select count(*) from res_table;";

      //
      // create the PreparedStatement instances
      //
      pstmtInitItrTable = con.prepareStatement(SQL_INIT_ITR_TABLE);                         // inits the iteration table
      pstmtInsertIntoResTable = con.prepareStatement(SQL_INSERT_INTO_RES_TABLE);            // accumulates the results
      pstmtDeleteFromTmpTable = con.prepareStatement(SQL_DELETE_FROM_TMP_TABLE);            // cleans out tmp table
      pstmtInsertIntoTmpTable = con.prepareStatement(SQL_INSERT_INTO_TMP_TABLE);            // gets next round of prereqs
      pstmtDeleteFromItrTable = con.prepareStatement(SQL_DELETE_FROM_ITR_TABLE);            // cleans out the tmp table
      pstmtInsertIntoItrTable = con.prepareStatement(SQL_INSERT_INTO_ITR_TABLE);            // copies from tmp to itr table
      pstmtSelectFromResTable = con.prepareStatement(SQL_SELECT_FROM_RES_TABLE);            // get accumulated results
//      pstmtSelectCountFromResTable = con.prepareStatement(SQL_SELECT_COUNT_FROM_RES_TABLE); // get accumulated results
      //
      // create the local tables
      //    res_table: accumulates the results (course prerequisites)
      //    itr_table: holds prerequisites for current loop iteration
      //    tmp_table: temporarily hold prerequisites
      //
      con.createStatement().executeUpdate(SQL_CREATE_RES_TABLE);
      con.createStatement().executeUpdate(SQL_CREATE_ITR_TABLE);
      con.createStatement().executeUpdate(SQL_CREATE_TMP_TABLE);
      //
      // initialize the iter table with first set of prerequisites
      //
      pstmtInitItrTable.setString(1, seedCourseId);
      pstmtInitItrTable.executeUpdate();
      //
      // enter the iteration loop
      //
      do {
        pstmtInsertIntoResTable.executeUpdate();  // accumulate the prerequisites
        pstmtDeleteFromTmpTable.executeUpdate();  // clean out the temporary table from previous iteration
        pstmtInsertIntoTmpTable.executeUpdate();  // insert new prerequisites into temporary table
        pstmtDeleteFromItrTable.executeUpdate();  // clean out the iteration table from previous iteration
      } while (0 < pstmtInsertIntoItrTable.executeUpdate()); // copy into iteration table, exit if no tuples

      rs = pstmtSelectFromResTable.executeQuery();
      //
      // get result set from result accumulation table and print out prerequisites
      //
      while (rs.next()) {
        System.out.println(rs.getString(1));
      }
    }
    catch (ClassNotFoundException | SQLException ex) {
      throw new RuntimeException("Unexpected exception attempting to get prerequisites", ex);
    }
    finally {
      //
      // clean up open resources
      // (result sets are automatically closed with their associated statements)
      //
      try {
        if (stmt != null) {
          stmt.close();
        }
        if (pstmtInitItrTable != null) {
          pstmtInsertIntoItrTable.close();
        }
        if (pstmtInsertIntoResTable != null) {
          pstmtInsertIntoResTable.close();
        }
        if (pstmtDeleteFromItrTable != null) {
          pstmtDeleteFromItrTable.close();
        }
        if (pstmtInsertIntoItrTable != null) {
          pstmtInsertIntoItrTable.close();
        }
        if (pstmtInsertIntoTmpTable != null) {
          pstmtInsertIntoTmpTable.close();
        }
        if (pstmtSelectFromResTable != null) {
          pstmtSelectFromResTable.close();
        }
        if (con != null) {
          con.createStatement().executeUpdate("drop table if exists res_table;");
          con.createStatement().executeUpdate("drop table if exists itr_table;");
          con.createStatement().executeUpdate("drop table if exists tmp_table;");
          con.close();
        }
      }
      catch (SQLException ex) {
        System.out.println(ex.getMessage());
      }
    }
  }

  private void load(String[] args) {
    String username = args[0];
    String password = args[1];
    String filepath = args[2];

    try {
      Class.forName(DRIVER_NAME);
    }
    catch (ClassNotFoundException e) {
      throw new RuntimeException("Unexpected exception attempting to set up database driver", e);
    }

    try (Connection conn = DriverManager.getConnection(CONNECT_STRING, username, password);
            PreparedStatement ps = conn.prepareStatement("INSERT INTO byu_cs_course (course_id,prereq_id) VALUES (?,?)");
            Statement stmt = conn.createStatement()) {
      conn.setSchema("byu_prereq");
      stmt.executeUpdate("create table if not exists byu_cs_course(\n" +
                            "course_id varchar(10) not null,\n" +
                            "prereq_id varchar(10));\n");

      stmt.executeUpdate("DELETE FROM byu_cs_course");

      try (BufferedReader br = new BufferedReader(new FileReader(filepath))){
        String line = br.readLine();
        while (line != null) {
          String[] courseData = line.split(",");
          ps.setString(1, courseData[0]);
          String prereq = courseData[1].equals("null") ? null : courseData[1];
          ps.setString(2, prereq);
          ps.executeUpdate();
          line = br.readLine();
        }
      }
      catch (IOException | SQLException e) {
        throw new RuntimeException("Unexpected exception loading byu_cs_prereq table", e);
      }
    }
    catch (SQLException e) {
      throw new RuntimeException("Unexpected exception attempting to set up database connection", e);
    }
  }


  private void printResults(String testName, ResultSet rs, double delta) throws SQLException {
    System.out.println("-----------------------------------------------------");
    System.out.println(String.format("\n%-25s%,15.2f microseconds", testName, delta));
    System.out.println("-----------------------------------------------------");
    //
    // get result set from result accumulation table and print out prerequisites
    //
    while (rs.next()) {
      System.out.println(rs.getString(1));
    }
    System.out.println("-----------------------------------------------------\n");
  }
}
