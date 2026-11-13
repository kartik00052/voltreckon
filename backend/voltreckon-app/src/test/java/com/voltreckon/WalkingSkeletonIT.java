package com.voltreckon;

import static org.assertj.core.api.Assertions.assertThat;

import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.web.server.LocalServerPort;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.test.context.DynamicPropertyRegistry;
import org.springframework.test.context.DynamicPropertySource;
import org.testcontainers.junit.jupiter.Container;
import org.testcontainers.junit.jupiter.Testcontainers;
import org.testcontainers.postgresql.PostgreSQLContainer;

@Testcontainers
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
class WalkingSkeletonIT {

    @Container
    static final PostgreSQLContainer POSTGRES = new PostgreSQLContainer("postgres:18");

    @DynamicPropertySource
    static void datasource(DynamicPropertyRegistry registry) {
        registry.add("spring.datasource.url", POSTGRES::getJdbcUrl);
        registry.add("spring.datasource.username", POSTGRES::getUsername);
        registry.add("spring.datasource.password", POSTGRES::getPassword);
    }

    @LocalServerPort
    int port;

    @Autowired
    JdbcTemplate jdbc;

    @Test
    void contextLoadsAndFlywayAppliedBaseline() {
        Integer migrations = jdbc.queryForObject(
                "select count(*) from voltreckon.flyway_schema_history where success and version is not null",
                Integer.class);
        assertThat(migrations).isEqualTo(1);

        String baseline = jdbc.queryForObject(
                "select description from voltreckon.flyway_schema_history where success and version is not null",
                String.class);
        assertThat(baseline).isEqualTo("extensions and schemas");

        Boolean extensionInstalled = jdbc.queryForObject(
                "select exists(select 1 from pg_extension where extname = 'btree_gist')", Boolean.class);
        assertThat(extensionInstalled).isTrue();

        Boolean schemaExists = jdbc.queryForObject(
                "select exists(select 1 from information_schema.schemata where schema_name = 'voltreckon')",
                Boolean.class);
        assertThat(schemaExists).isTrue();
    }

    @Test
    void actuatorHealthIsUp() throws Exception {
        HttpRequest request = HttpRequest
                .newBuilder(URI.create("http://localhost:" + port + "/actuator/health"))
                .GET()
                .build();

        HttpResponse<String> response = HttpClient.newHttpClient()
                .send(request, HttpResponse.BodyHandlers.ofString());

        assertThat(response.statusCode()).isEqualTo(200);
        assertThat(response.body()).contains("\"status\":\"UP\"");
    }
}
