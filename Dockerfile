FROM ubuntu:24.04

RUN apt-get update && apt-get install -y --no-install-recommends \
    bash curl jq adduser && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY main.sh ./
COPY assets/ ./assets/

RUN chmod +x main.sh

RUN addgroup --system appgroup && adduser --system --ingroup appgroup appuser

USER appuser

CMD ["bash", "main.sh"]
