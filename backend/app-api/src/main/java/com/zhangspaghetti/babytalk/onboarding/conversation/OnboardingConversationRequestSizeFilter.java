package com.zhangspaghetti.babytalk.onboarding.conversation;

import jakarta.servlet.FilterChain;
import jakarta.servlet.ReadListener;
import jakarta.servlet.ServletException;
import jakarta.servlet.ServletInputStream;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletRequestWrapper;
import jakarta.servlet.http.HttpServletResponse;
import java.io.BufferedReader;
import java.io.ByteArrayInputStream;
import java.io.IOException;
import java.io.InputStreamReader;
import java.nio.charset.StandardCharsets;
import org.springframework.http.MediaType;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;

@Component
public class OnboardingConversationRequestSizeFilter extends OncePerRequestFilter {

    static final int MAX_BODY_BYTES = 16 * 1024;
    private static final String PATH = "/api/v1/onboarding/conversations";

    @Override
    protected boolean shouldNotFilter(HttpServletRequest request) {
        var requestPath = request.getRequestURI();
        return !"POST".equals(request.getMethod())
                || !(PATH.equals(requestPath)
                || requestPath.matches("^/api/v1/onboarding/conversations/[^/]+/turns$"));
    }

    @Override
    protected void doFilterInternal(
            HttpServletRequest request,
            HttpServletResponse response,
            FilterChain filterChain
    ) throws ServletException, IOException {
        if (request.getContentLengthLong() > MAX_BODY_BYTES) {
            writeTooLarge(response);
            return;
        }
        var body = request.getInputStream().readNBytes(MAX_BODY_BYTES + 1);
        if (body.length > MAX_BODY_BYTES) {
            writeTooLarge(response);
            return;
        }
        filterChain.doFilter(new CachedBodyRequest(request, body), response);
    }

    private void writeTooLarge(HttpServletResponse response) throws IOException {
        response.setStatus(413);
        response.setContentType(MediaType.APPLICATION_JSON_VALUE);
        response.setCharacterEncoding(StandardCharsets.UTF_8.name());
        response.getWriter().write(
                "{\"status\":413,\"code\":\"onboarding_request_too_large\","
                        + "\"message\":\"请求体过大。\",\"details\":{}}");
    }

    private static final class CachedBodyRequest extends HttpServletRequestWrapper {
        private final byte[] body;

        private CachedBodyRequest(HttpServletRequest request, byte[] body) {
            super(request);
            this.body = body;
        }

        @Override
        public ServletInputStream getInputStream() {
            return new ByteArrayServletInputStream(body);
        }

        @Override
        public BufferedReader getReader() {
            var encoding = getCharacterEncoding() == null
                    ? StandardCharsets.UTF_8
                    : java.nio.charset.Charset.forName(getCharacterEncoding());
            return new BufferedReader(new InputStreamReader(getInputStream(), encoding));
        }

        @Override
        public int getContentLength() {
            return body.length;
        }

        @Override
        public long getContentLengthLong() {
            return body.length;
        }
    }

    private static final class ByteArrayServletInputStream extends ServletInputStream {
        private final ByteArrayInputStream input;

        private ByteArrayServletInputStream(byte[] body) {
            input = new ByteArrayInputStream(body);
        }

        @Override
        public int read() {
            return input.read();
        }

        @Override
        public boolean isFinished() {
            return input.available() == 0;
        }

        @Override
        public boolean isReady() {
            return true;
        }

        @Override
        public void setReadListener(ReadListener readListener) {
            // Spring MVC consumes this request synchronously.
        }
    }
}
