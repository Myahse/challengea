package com.challengea.api.security;

import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import java.io.IOException;
import java.util.List;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;

/** Reads the Bearer token; on success the principal is the user id (Long). */
@Component
public class JwtFilter extends OncePerRequestFilter {
  private final JwtService jwt;

  public JwtFilter(JwtService jwt) {
    this.jwt = jwt;
  }

  @Override
  protected void doFilterInternal(HttpServletRequest req, HttpServletResponse res, FilterChain chain)
      throws ServletException, IOException {
    var header = req.getHeader("Authorization");
    if (header != null && header.startsWith("Bearer ")) {
      jwt.verify(header.substring(7)).ifPresent(id -> SecurityContextHolder.getContext()
          .setAuthentication(new UsernamePasswordAuthenticationToken(id, null, List.of())));
    }
    chain.doFilter(req, res);
  }
}
