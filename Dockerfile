FROM maven:3.9.6-eclipse-temurin-21-alpine AS builder
WORKDIR /app
COPY pom.xml .
RUN mvn dependency:go-offline -B
COPY src ./src
RUN mvn package -DskipTests

FROM eclipse-temurin:21-jre
WORKDIR /app

# Python + media analysis dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    python3 python3-pip libgl1 libglib2.0-0 \
    && rm -rf /var/lib/apt/lists/*

COPY tools/requirements.txt ./tools/
RUN pip3 install --no-cache-dir -r tools/requirements.txt --break-system-packages || \
    pip3 install --no-cache-dir -r tools/requirements.txt

COPY tools ./tools
COPY --from=builder /app/target/*.jar app.jar

# Railway uses PORT env variable
ENV PORT=8080
EXPOSE ${PORT}

ENTRYPOINT ["java", "-Xmx512m", "-jar", "app.jar"]
