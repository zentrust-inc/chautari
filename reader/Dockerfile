# The reader service for our own server (deploy/server/setup.sh builds it).
FROM node:22-bookworm-slim
RUN apt-get update && apt-get install -y --no-install-recommends tesseract-ocr tesseract-ocr-hin tesseract-ocr-eng imagemagick ca-certificates curl \
 && curl -fsSL -o /usr/share/tesseract-ocr/5/tessdata/nep.traineddata https://github.com/tesseract-ocr/tessdata_best/raw/main/nep.traineddata \
 && apt-get purge -y curl && rm -rf /var/lib/apt/lists/*
WORKDIR /reader
COPY package.json package-lock.json ./
RUN npm ci --omit=dev
COPY *.mjs ./
ENV NODE_ENV=production
CMD ["node", "server.mjs"]
