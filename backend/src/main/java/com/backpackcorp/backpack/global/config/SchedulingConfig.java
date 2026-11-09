package com.backpackcorp.backpack.global.config;

import org.springframework.context.annotation.Configuration;
import org.springframework.scheduling.annotation.EnableScheduling;

// @Scheduled 작업(환율 수집)을 켠다. 서버를 여러 대 띄우면 대수만큼 실행되지만,
// 같은 (통화, 날짜)는 한 번만 저장되므로(유니크 키) 결과는 같다
@Configuration
@EnableScheduling
public class SchedulingConfig {
}
