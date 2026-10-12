FROM eclipse-temurin:21-jdk
RUN mkdir /work && chmod 755 /work
WORKDIR /work
USER 65534:65534
