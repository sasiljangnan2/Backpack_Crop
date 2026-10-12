# Code Convention - Frontend (Flutter / Dart)

**기준**: [Effective Dart](https://dart.dev/effective-dart) + `flutter_lints` + 아래 팀 규칙 + [공통 규칙](../common/code.md)

포맷은 사람이 맞추지 않고 `dart format`이 맞춘다. PR 전에 `dart format .`을 실행하고 `flutter analyze` 경고를 0개로 만든다.

## 1. 포맷

- `dart format` 결과를 그대로 쓴다 (스페이스 2칸, 한 줄 80자)
- 문자열은 **홑따옴표**(`'`)를 쓴다. 문자열 안에 `'`가 있을 때만 쌍따옴표를 쓴다
- 인자·리스트 끝에는 **trailing comma**를 붙인다 (포매터가 위젯 트리를 세로로 정리해 준다)
- 한 줄짜리 `if`에도 중괄호를 쓴다

```dart
return Padding(
  padding: const EdgeInsets.all(16),
  child: Text('여행 목록'),
);
```

## 2. 이름

| 대상 | 규칙 | 예 |
|---|---|---|
| 파일·폴더 | snake_case | `trip_list_screen.dart` |
| 클래스·enum·typedef | UpperCamelCase | `TripListScreen`, `ExpenseCategory` |
| 변수·함수·파라미터 | lowerCamelCase | `tripId`, `fetchTrips()` |
| 상수·enum 값 | lowerCamelCase (Dart는 대문자 상수를 쓰지 않는다) | `const maxMemberCount = 10;`, `ExpenseCategory.food` |
| private | 앞에 `_` | `_isLoading`, `_buildHeader()` |

- 화면 위젯은 `XxxScreen`, 재사용 위젯은 역할 이름 그대로 쓴다 (`TripCard`)

## 3. 폴더 구조

기능(feature) 단위로 나누고, 이름은 백엔드 도메인 이름과 맞춘다.

```
lib/
├── core/          공통: 테마, 라우팅, 네트워크(API 클라이언트), 유틸
├── features/
│   ├── trip/
│   │   ├── data/          API 호출, DTO(model), repository
│   │   └── presentation/  screen, widget, 상태 관리
│   ├── schedule/
│   ├── expense/
│   └── settlement/
└── main.dart
```

위 목록은 예시입니다. 현재 백엔드 도메인은 `trip`, `schedule`, `budget`, `expense`, `settlement`, `poll`, `task`, `notification`, `user`입니다.

## 4. 위젯

- `const` 생성자를 쓸 수 있으면 항상 `const`를 붙인다
- 상태가 없으면 `StatelessWidget`을 쓴다
- `build()`가 길어지면 `_buildXxx()` 메서드보다 **별도 위젯 클래스**로 뺀다 (리빌드 범위가 줄어든다)
- `build()` 안에서 API 호출이나 무거운 계산을 하지 않는다
- `async` 이후에 `BuildContext`를 쓸 때는 먼저 `if (!context.mounted) return;`을 확인한다

## 5. 타입·null 안전

- public API(함수 반환값, 필드)에는 타입을 적는다. 지역 변수는 `final` + 타입 추론을 쓴다
- 재할당하지 않는 변수는 `final`로 선언한다. `var`는 최소한으로 쓴다
- `dynamic`은 쓰지 않는다 (JSON 파싱 직후는 예외)
- `!` 강제 언래핑은 null이 아닌 이유가 확실할 때만 쓴다

## 6. 서버 연동

- 서버에서 받은 시각(`2026-10-12T03:00:00Z`)은 `DateTime.parse()` 후 `.toLocal()`로 변환해서 표시한다
- 날짜(`2026-10-12`)는 시간대 변환을 하지 않는다. 서버로 보낼 때는 `yyyy-MM-dd` 문자열로 보낸다. `toUtc().toIso8601String()`으로 보내면 한국 시간 기준 하루 전 날짜가 된다
- DTO에는 `fromJson` / `toJson`을 둔다. 화면에서 `Map`을 직접 다루지 않는다
- 서버 에러는 `ErrorResponse` 형식 하나로 오므로 공통 처리기에서 한 번에 처리한다. 분기는 `code` 값으로 한다
- API 주소와 키는 `--dart-define` 또는 env 파일로 넣는다

## 7. 기타

- `print()` 대신 `debugPrint()` 또는 로거를 쓴다
- 사용자에게 보이는 문자열은 한곳(상수 파일 또는 l10n)에 모은다
- 공개 API 문서 주석은 `///`로 쓴다
