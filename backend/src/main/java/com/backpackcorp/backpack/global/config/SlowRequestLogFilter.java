package com.backpackcorp.backpack.global.config;

import java.io.IOException;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.core.Ordered;
import org.springframework.core.annotation.Order;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;

import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import lombok.extern.slf4j.Slf4j;

// 오래 걸린 요청을 로그에 남긴다. 앱이 느리다는 말이 나오면 서버에서
//   docker compose logs --since 24h backend | grep "느린 요청"
// 으로 어느 화면(주소)이 느린지 본다. 주소만 남기고 쿼리 · 본문은 남기지 않는다
@Slf4j
@Component
@Order(Ordered.HIGHEST_PRECEDENCE)
public class SlowRequestLogFilter extends OncePerRequestFilter {

	private final long thresholdMillis;

	public SlowRequestLogFilter(@Value("${app.slow-request-ms:2000}") long thresholdMillis) {
		this.thresholdMillis = thresholdMillis;
	}

	@Override
	protected void doFilterInternal(HttpServletRequest request, HttpServletResponse response, FilterChain chain)
		throws ServletException, IOException {
		long started = System.nanoTime();
		try {
			chain.doFilter(request, response);
		} finally {
			long millis = (System.nanoTime() - started) / 1_000_000;
			if (millis >= thresholdMillis) {
				log.warn("느린 요청 {}ms {} {} → {}", millis, request.getMethod(), request.getRequestURI(),
					response.getStatus());
			}
		}
	}
}
