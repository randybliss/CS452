package org.byu.cs452;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.context.ApplicationContext;

import java.util.Arrays;

/**
 * @author blissrj
 */
@SpringBootApplication
public class CS452Application {
  public static void main(String[] args) {
    ApplicationContext ctx = SpringApplication.run(CS452Application.class, args);

    System.out.println("Let's inspect the beans provided by Spring Boot:");

    String[] beanNames = ctx.getBeanDefinitionNames();
    Arrays.sort(beanNames);
    for (String beanName : beanNames) {
      System.out.println(beanName);
    }
  }
}
