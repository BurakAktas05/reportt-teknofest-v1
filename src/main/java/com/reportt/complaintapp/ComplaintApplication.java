package com.reportt.complaintapp;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.boot.context.properties.ConfigurationPropertiesScan;

@SpringBootApplication
@ConfigurationPropertiesScan
public class ComplaintApplication {

    public static void main(String[] args) {
        SpringApplication.run(ComplaintApplication.class, args);
    }
}
