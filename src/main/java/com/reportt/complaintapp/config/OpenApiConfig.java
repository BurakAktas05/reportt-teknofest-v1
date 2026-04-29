package com.reportt.complaintapp.config;

import io.swagger.v3.oas.models.OpenAPI;
import io.swagger.v3.oas.models.info.Contact;
import io.swagger.v3.oas.models.info.Info;
import io.swagger.v3.oas.models.info.License;
import io.swagger.v3.oas.models.security.SecurityRequirement;
import io.swagger.v3.oas.models.security.SecurityScheme;
import io.swagger.v3.oas.models.Components;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

/**
 * Swagger / OpenAPI 3.0 yapılandırması.
 * Erişim: /swagger-ui/index.html
 */
@Configuration
public class OpenApiConfig {

    @Bean
    public OpenAPI reporttOpenAPI() {
        final String securitySchemeName = "bearerAuth";

        return new OpenAPI()
                .info(new Info()
                        .title("Reportt — Akıllı Şehir İhbar Sistemi API")
                        .description("""
                                Vatandaş ihbar oluşturma, memur inceleme, AI triyaj, 
                                kriptografik bütünlük, ısı haritası ve gamification 
                                endpointlerini içeren REST API dokümantasyonu.
                                """)
                        .version("2.0.0")
                        .contact(new Contact()
                                .name("Reportt Takımı")
                                .url("https://github.com/reportt"))
                        .license(new License()
                                .name("MIT License")
                                .url("https://opensource.org/licenses/MIT"))
                )
                .addSecurityItem(new SecurityRequirement().addList(securitySchemeName))
                .components(new Components()
                        .addSecuritySchemes(securitySchemeName,
                                new SecurityScheme()
                                        .name(securitySchemeName)
                                        .type(SecurityScheme.Type.HTTP)
                                        .scheme("bearer")
                                        .bearerFormat("JWT")
                                        .description("JWT token'ınızı girin (Bearer prefix gerekmez)")
                        )
                );
    }
}
