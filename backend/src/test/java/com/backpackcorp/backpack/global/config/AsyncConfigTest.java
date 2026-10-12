package com.backpackcorp.backpack.global.config;

import static org.assertj.core.api.Assertions.assertThat;

import java.util.concurrent.CompletableFuture;
import java.util.concurrent.TimeUnit;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.context.annotation.Import;
import org.springframework.scheduling.annotation.Async;
import org.springframework.stereotype.Component;
import org.springframework.test.context.ActiveProfiles;

@SpringBootTest
@ActiveProfiles("test")
@Import(AsyncConfigTest.Worker.class)
class AsyncConfigTest {

	@Autowired
	private Worker worker;

	@Test
	void Async_메서드는_호출한_스레드가_아닌_전용_스레드에서_실행된다() throws Exception {
		String threadName = worker.currentThreadName().get(5, TimeUnit.SECONDS);

		assertThat(threadName).startsWith("async-").isNotEqualTo(Thread.currentThread().getName());
	}

	// 테스트 클래스 안의 컴포넌트는 스캔되지 않으므로 @Import로 등록한다
	@Component
	static class Worker {

		@Async
		public CompletableFuture<String> currentThreadName() {
			return CompletableFuture.completedFuture(Thread.currentThread().getName());
		}
	}
}
