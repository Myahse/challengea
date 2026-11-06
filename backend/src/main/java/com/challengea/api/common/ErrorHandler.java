package com.challengea.api.common;

import java.util.Map;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.MethodArgumentNotValidException;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;

/** Every error is returned as {"error": code, "message": text}. */
@RestControllerAdvice
public class ErrorHandler {

  @ExceptionHandler(ApiException.class)
  ResponseEntity<Map<String, String>> api(ApiException e) {
    return ResponseEntity.status(e.status()).body(Map.of("error", e.code(), "message", e.getMessage()));
  }

  @ExceptionHandler(MethodArgumentNotValidException.class)
  ResponseEntity<Map<String, String>> invalid(MethodArgumentNotValidException e) {
    var field = e.getBindingResult().getFieldError();
    var message = field == null ? "Invalid request" : field.getField() + " " + field.getDefaultMessage();
    return ResponseEntity.status(HttpStatus.BAD_REQUEST).body(Map.of("error", "invalid_request", "message", message));
  }
}
