package br.com.bar.gestao.shared.config;

import io.swagger.v3.oas.models.Components;
import io.swagger.v3.oas.models.OpenAPI;
import io.swagger.v3.oas.models.info.Info;
import io.swagger.v3.oas.models.security.SecurityRequirement;
import io.swagger.v3.oas.models.security.SecurityScheme;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

/** Documentação OpenAPI/Swagger com autenticação Bearer (JWT). */
@Configuration
public class OpenApiConfig {

    public static final String BEARER = "bearer-jwt";

    @Bean
    OpenAPI openAPI() {
        return new OpenAPI()
                .info(new Info()
                        .title("Gestão de Bar — API")
                        .version("0.1.0")
                        .description("API do sistema de gestão do bar. Rotas /api/admin/** exigem token JWT "
                                + "obtido em POST /api/auth/login; rotas /api/public/** são abertas (cardápio)."))
                .components(new Components().addSecuritySchemes(BEARER, new SecurityScheme()
                        .type(SecurityScheme.Type.HTTP).scheme("bearer").bearerFormat("JWT")))
                .addSecurityItem(new SecurityRequirement().addList(BEARER));
    }
}
