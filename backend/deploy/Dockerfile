# scripts/deploy-cloud.ps1이 PC에서 만든 app.jar를 담는다.
# 메모리가 작은 무료 VM에서 Gradle 빌드를 돌리지 않으려고 소스 대신 jar를 올린다
# (소스에서 바로 빌드하는 이미지는 backend/Dockerfile)
FROM eclipse-temurin:21-jre-alpine
WORKDIR /app
# 업로드된 이미지가 쌓이는 폴더. docker-compose.yml이 볼륨을 붙인다
RUN addgroup -S app && adduser -S app -G app && mkdir storage && chown app:app storage
COPY --chown=app:app app.jar ./app.jar
USER app

ENV SPRING_PROFILES_ACTIVE=prod
EXPOSE 8080
ENTRYPOINT ["java", "-jar", "/app/app.jar"]
