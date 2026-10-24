FROM eclipse-temurin:21-jdk AS builder
WORKDIR /app

# 의존성 레이어 캐시
COPY gradle ./gradle
COPY gradlew build.gradle.kts settings.gradle.kts ./
RUN chmod +x ./gradlew && ./gradlew dependencies --no-daemon

COPY src ./src
RUN ./gradlew bootJar -x test --no-daemon

FROM eclipse-temurin:21-jre-alpine
WORKDIR /app
# 업로드된 이미지가 쌓이는 폴더. 컨테이너를 새로 만들어도 남도록 볼륨을 붙여 실행한다
#   docker run -v backpack-storage:/app/storage ...
RUN addgroup -S app && adduser -S app -G app && mkdir storage && chown app:app storage
COPY --from=builder --chown=app:app /app/build/libs/*.jar ./app.jar
USER app

ENV SPRING_PROFILES_ACTIVE=prod
ENV JAVA_TOOL_OPTIONS="-XX:MaxRAMPercentage=75.0"
EXPOSE 8080
ENTRYPOINT ["java", "-jar", "/app/app.jar"]
