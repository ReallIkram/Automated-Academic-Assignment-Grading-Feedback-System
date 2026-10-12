FROM python:3.12-slim
RUN mkdir /work && chmod 755 /work
WORKDIR /work
USER 65534:65534
