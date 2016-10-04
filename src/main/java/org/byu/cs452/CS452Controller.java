package org.byu.cs452;

import org.byu.cs452.persistence.JsonStudent;
import org.byu.cs452.persistence.Student;
import org.byu.cs452.persistence.UniversityStore;
import org.springframework.web.bind.annotation.*;

import java.util.List;

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
    return universityStore.readStudent(id);
  }

  @RequestMapping(path = "/student", method = RequestMethod.GET)
  public List<Student> getStudents() {
    return universityStore.readStudents();
  }

  @RequestMapping(path = "json/student{id}", method = RequestMethod.GET)
  public JsonStudent getJsonStudent(@PathVariable String id) {
    return universityStore.readJsonStudent(id);
  }

  @RequestMapping(path = "json/student{id}", method = RequestMethod.POST)
  public void createJsonStudent(@PathVariable String id,
                                @RequestParam("name") String name,
                                @RequestParam("dept") String departmentName,
                                @RequestParam(value = "totcred", defaultValue = "0") String totalCredits)
  {
    int rc = universityStore.createJsonStudent(id, name, departmentName, Integer.parseInt(totalCredits));
    if (rc != 1) {
      throw new RuntimeException("Failed to create Json Student record for id: " + id);
    }
  }
}
