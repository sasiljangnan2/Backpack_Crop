# 출시 빌드(R8) 규칙.
# 영수증 OCR 플러그인(google_mlkit_text_recognition)은 데바나가리(힌디어) 모델 클래스도 가리키지만,
# 앱에는 한국어 · 일본어 · 중국어 · 라틴 모델만 넣었다 (build.gradle.kts). 없는 클래스는 무시한다
-dontwarn com.google.mlkit.vision.text.devanagari.**
