FROM maven:3.9.6-eclipse-temurin-21-alpine AS builder
WORKDIR /app
COPY pom.xml .
RUN mvn dependency:go-offline -B
COPY src ./src
RUN mvn package -DskipTests

FROM eclipse-temurin:21-jre
WORKDIR /app
RUN apt-get update && apt-get install -y python3 python3-pip libgl1-mesa-glx libglib2.0-0 && rm -rf /var/lib/apt/lists/*
COPY tools/requirements.txt ./tools/
RUN pip3 install --no-cache-dir -r tools/requirements.txt --break-system-packages || pip3 install --no-cache-dir -r tools/requirements.txt
COPY tools ./tools
COPY --from=builder /app/target/*.jar app.jar
EXPOSE 8080
ENTRYPOINT ["java", "-jar", "app.jar"]
