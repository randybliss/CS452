package org.byu.cs452.persistence;

/**
 * @author blissrj
 */
public class NotFoundException extends RuntimeException {

  public NotFoundException(String message) {
    super(message);
  }
}
