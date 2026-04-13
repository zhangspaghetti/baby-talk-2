package com.zhangspaghetti.babytalk;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.boot.context.properties.ConfigurationPropertiesScan;

@SpringBootApplication
@ConfigurationPropertiesScan
public class BabyTalkBackendApplication {

    public static void main(String[] args) {
        SpringApplication.run(BabyTalkBackendApplication.class, args);
    }
}
