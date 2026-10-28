package com.backpackcorp.backpack.replan.service;

import java.net.http.HttpClient;
import java.time.Duration;
import java.util.Base64;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.concurrent.CompletionService;
import java.util.concurrent.ExecutionException;
import java.util.concurrent.ExecutorCompletionService;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.Future;
import java.util.concurrent.TimeUnit;
import java.util.stream.Collectors;
import java.util.stream.Stream;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.core.ParameterizedTypeReference;
import org.springframework.http.MediaType;
import org.springframework.http.client.JdkClientHttpRequestFactory;
import org.springframework.stereotype.Component;
import org.springframework.web.client.HttpClientErrorException;
import org.springframework.web.client.RestClient;

// Google Gemini API (generateContent). 무료 등급 키로 쓴다 (https://aistudio.google.com/apikey).
// 무료 등급은 보낸 내용이 구글 제품 개선에 쓰일 수 있으므로 일정 이름 · 장소 · 시간과 영수증 사진만 보낸다
// (회원 이름 · 이메일은 보내지 않는다)
@Component
public class GeminiClient {

	private static final ParameterizedTypeReference<Map<String, Object>> JSON = new ParameterizedTypeReference<>() {
	};
	private static final ExecutorService EXECUTOR = Executors.newVirtualThreadPerTaskExecutor();

	private final RestClient client;
	private final String apiKey;
	// 한꺼번에 묻는 모델들. 무료 등급은 모델마다 붐비는 정도가 달라(503 · 수십 초 대기) 가장 먼저 온 답을 쓴다.
	// 모델마다 무료 한도가 따로라 한 모델의 한도를 빨리 쓰지도 않는다
	private final List<String> models;
	// 기다리는 시간. 넘으면 포기하고 부르는 쪽이 규칙 기반 추천을 쓴다
	private final Duration budget;

	public GeminiClient(
		@Value("${ai.gemini.url}") String url,
		@Value("${ai.gemini.api-key:}") String apiKey,
		@Value("${ai.gemini.model}") String model,
		@Value("${ai.gemini.fallback-models:}") List<String> fallbackModels,
		@Value("${ai.gemini.timeout:25s}") Duration budget) {
		HttpClient httpClient = HttpClient.newBuilder().connectTimeout(Duration.ofSeconds(5)).build();
		JdkClientHttpRequestFactory factory = new JdkClientHttpRequestFactory(httpClient);
		factory.setReadTimeout(budget);
		this.client = RestClient.builder().baseUrl(url).requestFactory(factory).build();
		this.apiKey = apiKey == null ? "" : apiKey.trim();
		this.models = Stream.concat(Stream.of(model), fallbackModels.stream())
			.map(String::trim)
			.filter(m -> !m.isEmpty())
			.distinct()
			.toList();
		this.budget = budget;
	}

	public boolean enabled() {
		return !apiKey.isEmpty();
	}

	// JSON으로만 답하게 한다. 모든 모델이 실패하거나 시간 안에 답하지 않으면 RuntimeException
	public String generateJson(String instruction, String prompt, Map<String, Object> schema) {
		return generateJson(instruction, List.of(Map.of("text", prompt)), schema, 0.4);
	}

	// 글과 사진을 함께 보낸다 (영수증 읽기). 사진은 imagePart로 만든다
	public String generateJson(String instruction, List<Map<String, Object>> parts, Map<String, Object> schema,
		double temperature) {
		Map<String, Object> config = new HashMap<>();
		config.put("responseMimeType", "application/json");
		config.put("temperature", temperature);
		config.put("responseSchema", schema);
		Map<String, Object> body = Map.of(
			"systemInstruction", Map.of("parts", List.of(Map.of("text", instruction))),
			"contents", List.of(Map.of("role", "user", "parts", parts)),
			"generationConfig", config);
		CompletionService<String> answers = new ExecutorCompletionService<>(EXECUTOR);
		List<Future<String>> asked = models.stream()
			.map(model -> answers.submit(() -> ask(model, body, config)))
			.toList();
		long deadline = System.nanoTime() + budget.toNanos();
		RuntimeException last = null;
		try {
			for (int i = 0; i < asked.size(); i++) {
				Future<String> first = answers.poll(deadline - System.nanoTime(), TimeUnit.NANOSECONDS);
				if (first == null) {
					break;
				}
				try {
					return first.get();
				} catch (ExecutionException e) {
					// 붐빔(503) · 한도 초과(429) · 없는 모델(404) · 시간 초과면 다른 모델의 답을 기다린다
					last = e.getCause() instanceof RuntimeException cause ? cause : new IllegalStateException(e);
				}
			}
		} catch (InterruptedException e) {
			Thread.currentThread().interrupt();
		} finally {
			asked.forEach(f -> f.cancel(true));
		}
		throw last != null ? last : new IllegalStateException("Gemini가 " + budget.toSeconds() + "초 안에 답하지 않았어요");
	}

	public static Map<String, Object> imagePart(String mimeType, byte[] data) {
		return Map.of("inlineData", Map.of("mimeType", mimeType, "data", Base64.getEncoder().encodeToString(data)));
	}

	private String ask(String model, Map<String, Object> body, Map<String, Object> config) {
		try {
			return textOf(post(model, body));
		} catch (HttpClientErrorException.BadRequest e) {
			// 스키마 형식을 받지 않는 모델이면 스키마 없이 한 번 더 (지시문에 형식이 있다)
			Map<String, Object> plain = new HashMap<>(body);
			Map<String, Object> plainConfig = new HashMap<>(config);
			plainConfig.remove("responseSchema");
			plain.put("generationConfig", plainConfig);
			return textOf(post(model, plain));
		}
	}

	private Map<String, Object> post(String model, Map<String, Object> body) {
		return client.post()
			.uri("/models/{model}:generateContent", model)
			.header("x-goog-api-key", apiKey)
			.contentType(MediaType.APPLICATION_JSON)
			.body(body)
			.retrieve()
			.body(JSON);
	}

	// candidates[0].content.parts[].text (생각 과정 thought=true는 뺀다)
	@SuppressWarnings("unchecked")
	static String textOf(Map<String, Object> response) {
		if (response == null || !(response.get("candidates") instanceof List<?> candidates) || candidates.isEmpty()) {
			throw new IllegalStateException("Gemini 응답에 후보가 없어요");
		}
		Map<String, Object> first = (Map<String, Object>)candidates.getFirst();
		if (!(first.get("content") instanceof Map<?, ?> content)
			|| !(content.get("parts") instanceof List<?> parts)) {
			throw new IllegalStateException("Gemini 응답이 비었어요: " + first.get("finishReason"));
		}
		String text = parts.stream()
			.map(part -> (Map<String, Object>)part)
			.filter(part -> !Boolean.TRUE.equals(part.get("thought")))
			.map(part -> part.get("text"))
			.filter(t -> t instanceof String)
			.map(String.class::cast)
			.collect(Collectors.joining());
		if (text.isBlank()) {
			throw new IllegalStateException("Gemini 응답에 글이 없어요");
		}
		return text;
	}
}
