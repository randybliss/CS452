package org.byu.cs452;

import org.byu.cs452.persistence.Student;
import org.byu.cs452.persistence.UniversityStore;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestMethod;
import org.springframework.web.bind.annotation.RestController;

/**
 * @author blissrj
 */
@RestController
public class CS452Controller {
  private UniversityStore universityStore = new UniversityStore();

  @RequestMapping("/")
  public String index() {
    return "Greetings from CS452";
  }

  @RequestMapping(path = "/student/{id}", method = RequestMethod.GET)
  public Student getStudent(@PathVariable String id) {
    return universityStore.getStudent(id);
  }
}
