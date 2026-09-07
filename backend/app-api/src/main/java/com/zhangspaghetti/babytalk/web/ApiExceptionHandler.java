package com.zhangspaghetti.babytalk.web;

import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.ConstraintViolationException;
import java.time.Instant;
import java.util.LinkedHashMap;
import java.util.Map;
import java.util.stream.Collectors;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.validation.FieldError;
import org.springframework.http.converter.HttpMessageNotReadableException;
import org.springframework.web.servlet.NoHandlerFoundException;
import org.springframework.web.bind.MethodArgumentNotValidException;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;
import org.springframework.web.servlet.resource.NoResourceFoundException;

@RestControllerAdvice
public class ApiExceptionHandler {

    private static final Logger log = LoggerFactory.getLogger(ApiExceptionHandler.class);

    @ExceptionHandler(com.zhangspaghetti.babytalk.practice.scene.SceneGenerationRequest.InvalidSceneSourceException.class)
    public ResponseEntity<Map<String, Object>> handleInvalidSceneSource() {
        return ResponseEntity.badRequest()
                .body(errorBody(HttpStatus.BAD_REQUEST, "invalid_scene_source", "场景来源不合法。", Map.of()));
    }

    @ExceptionHandler(ContractException.class)
    public ResponseEntity<Map<String, Object>> handleContract(ContractException exception) {
        return ResponseEntity.status(exception.status())
                .body(errorBody(exception.status(), exception.code(), exception.getMessage(), exception.details()));
    }

    @ExceptionHandler(MethodArgumentNotValidException.class)
    public ResponseEntity<Map<String, Object>> handleValidation(MethodArgumentNotValidException exception) {
        var fieldErrors = exception.getBindingResult()
                .getFieldErrors()
                .stream()
                .collect(Collectors.toMap(
                        FieldError::getField,
                        fieldError -> fieldError.getDefaultMessage() == null ? "invalid" : fieldError.getDefaultMessage(),
                        (left, right) -> left,
                        LinkedHashMap::new
                ));
        return ResponseEntity.badRequest()
                .body(errorBody(HttpStatus.BAD_REQUEST, "validation_failed", "请求参数不合法。", Map.of("fields", fieldErrors)));
    }

    @ExceptionHandler(HttpMessageNotReadableException.class)
    public ResponseEntity<Map<String, Object>> handleUnreadableBody(
            HttpMessageNotReadableException exception,
            HttpServletRequest request
    ) {
        if (request != null && "/api/v1/practice/scene-generations".equals(request.getRequestURI())) {
            return ResponseEntity.badRequest()
                    .body(errorBody(HttpStatus.BAD_REQUEST, "invalid_scene_source", "场景来源不合法。", Map.of()));
        }
        return ResponseEntity.badRequest()
                .body(errorBody(HttpStatus.BAD_REQUEST, "invalid_request_body", "请求体必须是合法 JSON object。", Map.of()));
    }

    @ExceptionHandler(ConstraintViolationException.class)
    public ResponseEntity<Map<String, Object>> handleConstraintViolation(ConstraintViolationException exception) {
        return ResponseEntity.badRequest()
                .body(errorBody(HttpStatus.BAD_REQUEST, "validation_failed", "请求参数不合法。", Map.of()));
    }

    @ExceptionHandler({NoHandlerFoundException.class, NoResourceFoundException.class})
    public ResponseEntity<Map<String, Object>> handleNotFound(Exception exception) {
        return ResponseEntity.status(HttpStatus.NOT_FOUND)
                .body(errorBody(HttpStatus.NOT_FOUND, "not_found", "接口不存在。", Map.of()));
    }

    @ExceptionHandler(Exception.class)
    public ResponseEntity<Map<String, Object>> handleUnexpected(Exception exception) {
        var correlationId = SafeCorrelationId.create();
        log.error("app-api unexpected failure correlationId={}, type={}", correlationId, exception.getClass().getSimpleName());
        return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                .body(errorBody(HttpStatus.INTERNAL_SERVER_ERROR, "internal_error", "服务端处理失败。", Map.of(), correlationId));
    }

    private Map<String, Object> errorBody(HttpStatus status, String code, String message, Map<String, Object> details) {
        return errorBody(status, code, message, details, SafeCorrelationId.create());
    }

    private Map<String, Object> errorBody(
            HttpStatus status,
            String code,
            String message,
            Map<String, Object> details,
            String correlationId
    ) {
        return Map.of(
                "timestamp", Instant.now().toString(),
                "status", status.value(),
                "code", code,
                "message", message,
                "details", details == null ? Map.of() : details,
                "correlationId", correlationId
        );
    }
}
