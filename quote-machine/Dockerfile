FROM node:20-bookworm-slim

WORKDIR /app

RUN apt-get update && apt-get install -y --no-install-recommends \
    git \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

RUN git clone --depth=1 https://github.com/you209/Quote-Machine.git /app

RUN npm ci --omit=dev || npm install --omit=dev

COPY run.sh /run.sh
RUN chmod a+x /run.sh

EXPOSE 3000

CMD ["/run.sh"]
