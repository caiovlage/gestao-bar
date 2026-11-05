package br.com.bar.gestao;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.boot.context.properties.ConfigurationPropertiesScan;

@SpringBootApplication
@ConfigurationPropertiesScan
public class GestaoBarApplication {

    public static void main(String[] args) {
        SpringApplication.run(GestaoBarApplication.class, args);
    }
}
