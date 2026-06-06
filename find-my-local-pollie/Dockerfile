FROM node:20-bookworm-slim

WORKDIR /app

RUN apt-get update && apt-get install -y --no-install-recommends \
    git \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

RUN git clone --depth=1 https://github.com/you209/Find-My-Local-Pollie.git /app

RUN npm ci || npm install
RUN npx prisma generate || true
RUN npm run build

COPY run.sh /run.sh
RUN chmod a+x /run.sh

EXPOSE 3000

CMD ["/run.sh"]
