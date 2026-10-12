# Code Convention - Backend (Java / Spring)

**기준**: [네이버 캠퍼스 핵데이 Java 코딩 컨벤션](https://naver.github.io/hackday-conventions-java/) + 아래 팀 규칙 + [공통 규칙](../common/code.md)

적용 대상: `backend/` 폴더

## 1. 포맷

- 들여쓰기는 **탭**, 한 줄 최대 **120자**
- 한 줄에 한 문장만 쓴다. 중괄호는 K&R 스타일 (`if (...) {`처럼 같은 줄에서 연다)
- `if`, `for`, `while`은 한 줄이어도 **중괄호 필수**
- 파일 끝에 개행 1개를 둔다. 와일드카드 import(`*`)는 쓰지 않는다
- import 순서는 IntelliJ 기본 설정을 따른다 (`Ctrl+Alt+O`로 정리)

## 2. 이름

| 대상 | 규칙 | 예 |
|---|---|---|
| 패키지 | 소문자, 도메인 단위 | `com.backpackcorp.backpack.trip` |
| 클래스 | UpperCamelCase, 명사 | `TripService`, `BudgetItem` |
| 엔티티 | 단수형 | `User`, `Trip` |
| 메서드·변수 | lowerCamelCase, 메서드는 동사로 시작 | `findTrip()`, `tripId` |
| 상수·enum 값 | UPPER_SNAKE_CASE | `MAX_MEMBER_COUNT`, `ErrorCode.NOT_TRIP_MEMBER` |
| DB 테이블·컬럼 | snake_case, 테이블은 복수형 | `budget_items`, `trip_id` |
| URL | kebab-case, 복수형 명사 | `/api/trips/{tripId}/budget-items` |

## 3. 계층 구조

- 도메인 폴더 안에서 `controller / service / repository / domain / dto`로 나눈다
- 클래스 접미사: `XxxController`, `XxxService`, `XxxRepository`, `XxxRequest`, `XxxResponse`
  - 요청·응답이 아닌 계층 간 전달용 DTO는 `XxxDto`
- **Controller**는 요청을 받고 응답만 만든다. 비즈니스 로직은 **Service**에 둔다
- 엔티티를 그대로 응답하지 않는다. 항상 DTO로 바꿔서 내려준다
- 공통 코드(설정, 예외, 보안, 공통 DTO·엔티티)는 `global`에 둔다
- Service는 인터페이스 없이 **클래스 하나**로 만든다 (`UserService` + `UserServiceImpl` 구조를 쓰지 않는다)

## 4. DTO·엔티티

- DTO는 `record`로 만든다. 엔티티 → DTO 변환은 `XxxResponse.from(entity)` 정적 메서드로 한다
- 요청 DTO에는 검증 어노테이션(`@NotBlank`, `@Size` 등)을 붙이고, Controller에서 `@Valid`로 검증한다
- 엔티티에는 `@Getter`와 `@NoArgsConstructor(access = AccessLevel.PROTECTED)`만 쓴다. **`@Setter`, `@Data` 금지**
- 값 변경은 의미 있는 이름의 메서드로 한다: `trip.changeName(name)`
- 연관관계는 기본 `FetchType.LAZY`, enum은 `@Enumerated(EnumType.STRING)`
- 시각(언제)은 `Instant`(UTC), 날짜(며칠)는 `LocalDate`로 저장하고 ISO-8601 문자열로 응답한다

```java
public record TripResponse(
	UUID id,
	String name,
	LocalDate startDate
) {

	public static TripResponse from(Trip trip) {
		return new TripResponse(trip.getId(), trip.getName(), trip.getStartDate());
	}
}
```

## 5. 의존성 주입·트랜잭션

- 생성자 주입만 쓴다: `@RequiredArgsConstructor` + `private final`. **필드 `@Autowired` 금지**
- Service 클래스에 `@Transactional(readOnly = true)`를 붙이고, 쓰기 메서드에만 `@Transactional`을 붙인다

## 6. 예외 처리

- `throw new BaseException(ErrorCode.XXX)` 하나로 통일한다. 새 에러는 `ErrorCode`에 추가한다
- 응답 형식은 `ErrorResponse` 하나로 하고, `GlobalExceptionHandler`가 처리한다
- `catch`로 예외를 삼키지 않는다. 잡으면 로그를 남기거나 다시 던진다

## 7. DB 마이그레이션

- 스키마 변경은 Flyway SQL로만 한다. `V1__init.sql`은 고치지 않고 `V2__설명.sql`처럼 새 파일을 추가한다

## 8. 테스트

- 테스트 메서드 이름은 한글로 써도 된다: `여행_멤버가_아니면_403()`
- given / when / then 순서로 쓴다
- PR 전에 `./gradlew build`가 통과해야 한다

## 9. 로그

- `System.out.println` 대신 `@Slf4j`의 `log`를 쓴다
