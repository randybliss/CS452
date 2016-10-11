package org.byu.cs452;

import org.byu.cs452.persistence.NotFoundException;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestControllerAdvice;

import javax.servlet.http.HttpServletResponse;
import java.io.IOException;

/**
 * @author blissrj
 */
@RestControllerAdvice
public class CS452ControllerExceptionHandler {
  @ResponseStatus(HttpStatus.NOT_FOUND)
  @ExceptionHandler(NotFoundException.class)
  public void handleNotFoundException(NotFoundException ex, HttpServletResponse response) {
    try {
      response.sendError(HttpStatus.NOT_FOUND.value(), ex.getMessage());
    }
    catch (IOException ignore) {
    }
  }
}
