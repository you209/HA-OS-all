FROM python:3.11-slim

WORKDIR /app

RUN apt-get update && apt-get install -y --no-install-recommends \
    git \
    ca-certificates \
    libatlas-base-dev \
    libglib2.0-0 \
    libsm6 \
    libxext6 \
    libxrender-dev \
    tesseract-ocr \
    ffmpeg \
    curl \
    && rm -rf /var/lib/apt/lists/*

RUN curl -fsSL https://deb.nodesource.com/setup_20.x | bash - && \
    apt-get install -y nodejs && \
    rm -rf /var/lib/apt/lists/*

RUN git clone --depth=1 https://github.com/you209/Family-Database.git /app

RUN pip install --no-cache-dir -r /app/backend/requirements.txt
RUN cd /app/frontend && npm install && npm run build

RUN mkdir -p /app/data /app/media/originals /app/media/thumbnails

COPY run.sh /run.sh
RUN chmod a+x /run.sh

EXPOSE 5050

CMD ["/run.sh"]
