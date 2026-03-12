FROM ubuntu:24.04

RUN apt-get update && apt-get install -y --no-install-recommends \
    bash curl jq && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY main.sh ./
COPY assets/ ./assets/

RUN chmod +x main.sh

CMD ["bash", "main.sh"]
