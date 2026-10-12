package com.backpackcorp.backpack.global.config;

import org.springframework.context.annotation.Configuration;
import org.springframework.scheduling.annotation.EnableAsync;

// @Async가 붙은 메서드를 요청 스레드가 아닌 별도 스레드에서 실행한다 (예: 푸시 발송을 기다리지 않고 응답).
// 같은 클래스 안에서 부르면 비동기로 돌지 않는다. 다른 빈에서 불러야 한다.
// 트랜잭션 안에서 부르면 커밋 전에 실행될 수 있으니, 저장된 데이터를 읽어야 하면
// @TransactionalEventListener(phase = AFTER_COMMIT)와 함께 쓴다.
//
// ponytail: 스레드 풀은 Spring Boot가 만들어 주는 것을 쓴다 (스레드 8개, 대기열 무제한).
//  작업이 밀리면 application.yaml의 spring.task.execution.pool에서 크기를 정한다
@Configuration
@EnableAsync
public class AsyncConfig {
}
