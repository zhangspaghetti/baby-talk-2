package com.zhangspaghetti.babytalk.admin.auth;

import jakarta.validation.Valid;
import jakarta.validation.ConstraintViolationException;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import java.time.Instant;
import java.util.LinkedHashMap;
import java.util.Map;
import java.util.stream.Collectors;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.AccessDeniedException;
import org.springframework.security.core.Authentication;
import org.springframework.validation.FieldError;
import org.springframework.web.bind.MethodArgumentNotValidException;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.bind.annotation.RestControllerAdvice;

@RestController
@RequestMapping("/api/admin")
public class AdminAuthController {

    private final AdminAuthService adminAuthService;

    public AdminAuthController(AdminAuthService adminAuthService) {
        this.adminAuthService = adminAuthService;
    }

    @PostMapping("/auth/login")
    public AdminAuthService.TokenResponse login(@Valid @RequestBody LoginRequest request) {
        return adminAuthService.login(request.username(), request.password());
    }

    @PostMapping("/auth/refresh")
    public AdminAuthService.TokenResponse refresh(@Valid @RequestBody RefreshTokenRequest request) {
        return adminAuthService.refresh(request.refreshToken());
    }

    @PostMapping("/auth/logout")
    public AdminAuthService.LogoutResponse logout(@Valid @RequestBody RefreshTokenRequest request) {
        return adminAuthService.logout(request.refreshToken());
    }

    @GetMapping("/me")
    public AdminAuthService.MeResponse me(Authentication authentication) {
        return adminAuthService.me(authentication);
    }

    record LoginRequest(
            @NotBlank(message = "username 不能为空。") @Size(max = 64, message = "username 过长。") String username,
            @NotBlank(message = "password 不能为空。") @Size(max = 128, message = "password 过长。") String password
    ) {
    }

    record RefreshTokenRequest(
            @NotBlank(message = "refreshToken 不能为空。") @Size(max = 4096, message = "refreshToken 过长。") String refreshToken
    ) {
    }
}

@RestControllerAdvice
class AdminApiExceptionHandler {

    @ExceptionHandler(AdminApiContractException.class)
    ResponseEntity<Map<String, Object>> handleContract(AdminApiContractException exception) {
        return ResponseEntity.status(exception.status())
                .body(errorBody(exception.status(), exception.code(), exception.getMessage(), exception.details()));
    }

    @ExceptionHandler(MethodArgumentNotValidException.class)
    ResponseEntity<Map<String, Object>> handleValidation(MethodArgumentNotValidException exception) {
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

    @ExceptionHandler(ConstraintViolationException.class)
    ResponseEntity<Map<String, Object>> handleConstraintViolation(ConstraintViolationException exception) {
        return ResponseEntity.badRequest()
                .body(errorBody(HttpStatus.BAD_REQUEST, "validation_failed", exception.getMessage(), Map.of()));
    }

    @ExceptionHandler(AccessDeniedException.class)
    ResponseEntity<Map<String, Object>> handleAccessDenied(AccessDeniedException exception) {
        return ResponseEntity.status(HttpStatus.FORBIDDEN)
                .body(errorBody(HttpStatus.FORBIDDEN, "forbidden", "权限不足。", Map.of()));
    }

    @ExceptionHandler(Exception.class)
    ResponseEntity<Map<String, Object>> handleUnexpected(Exception exception) {
        return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                .body(errorBody(HttpStatus.INTERNAL_SERVER_ERROR, "internal_error", "服务端处理失败。", Map.of()));
    }

    private Map<String, Object> errorBody(HttpStatus status, String code, String message, Map<String, Object> details) {
        return Map.of(
                "timestamp", Instant.now().toString(),
                "status", status.value(),
                "code", code,
                "message", message,
                "details", details == null ? Map.of() : details
        );
    }
}
