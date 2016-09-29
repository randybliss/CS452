package org.byu.cs452.persistence;

import java.sql.Connection;

/**
 * @author blissrj
 */
interface ConnectionFactory {
  Connection getConnection();
}
