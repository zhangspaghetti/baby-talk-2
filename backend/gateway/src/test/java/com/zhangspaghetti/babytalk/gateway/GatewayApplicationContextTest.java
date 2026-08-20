package com.zhangspaghetti.babytalk.gateway;

import static org.assertj.core.api.Assertions.assertThat;

import java.net.URI;
import java.time.Duration;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.cloud.gateway.route.RouteDefinitionLocator;
import org.springframework.context.ApplicationContext;
import org.springframework.data.redis.connection.ReactiveRedisConnectionFactory;
import org.springframework.data.redis.connection.lettuce.LettuceConnectionFactory;
import org.springframework.security.web.server.SecurityWebFilterChain;

@SpringBootTest(
        classes = GatewayApplication.class,
        webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT,
        properties = {
                "app.gateway.admin-jwt-secret=babytalk-gateway-context-test-secret-1234567890",
                "babytalk.candidate.id=btqa-context-test",
                "babytalk.candidate.required-migration-version=35",
                "spring.data.redis.host=127.0.0.1",
                "spring.data.redis.port=1"
        }
)
class GatewayApplicationContextTest {

    @Autowired
    private ApplicationContext applicationContext;

    @Autowired
    private RouteDefinitionLocator routeDefinitionLocator;

    @Autowired
    private ReactiveRedisConnectionFactory redisConnectionFactory;

    @Autowired
    private SecurityWebFilterChain securityWebFilterChain;

    @Test
    void fullGatewayContextStartsWithSecurityRedisAndAdminRoute() {
        assertThat(applicationContext).isNotNull();
        assertThat(securityWebFilterChain).isNotNull();
        assertThat(redisConnectionFactory).isInstanceOf(LettuceConnectionFactory.class);
        var lettuceConnectionFactory = (LettuceConnectionFactory) redisConnectionFactory;
        assertThat(lettuceConnectionFactory.getStandaloneConfiguration().getHostName())
                .isEqualTo("127.0.0.1");
        assertThat(lettuceConnectionFactory.getStandaloneConfiguration().getPort()).isEqualTo(1);

        var routes = routeDefinitionLocator.getRouteDefinitions()
                .collectList()
                .block(Duration.ofSeconds(5));
        assertThat(routes).isNotNull().anySatisfy(route -> {
            assertThat(route.getId()).isEqualTo("admin-api");
            assertThat(route.getUri()).isEqualTo(URI.create("http://localhost:8081"));
            assertThat(route.getPredicates()).singleElement().satisfies(predicate -> {
                assertThat(predicate.getName()).isEqualTo("Path");
                assertThat(predicate.getArgs()).containsValue("/api/admin/**");
            });
        });
    }
}
