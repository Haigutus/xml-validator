# syntax=docker/dockerfile:1
# Cloud Run free-tier oriented: scale-to-zero, baked XSD, fast gunicorn boot.
# Optional local override: -v ./XSD:/app/XSD:ro
FROM ghcr.io/astral-sh/uv:python3.13-bookworm-slim

WORKDIR /app

RUN groupadd --system app && useradd --system --gid app --home /app --shell /usr/sbin/nologin app

COPY pyproject.toml uv.lock ./
RUN uv sync --frozen --no-dev \
    && rm -rf /root/.cache/uv

COPY app.py xsd.py ./
COPY assets ./assets
COPY examples ./examples
COPY XSD ./XSD

ARG GIT_COMMIT_COUNT=0
RUN echo "0.2.${GIT_COMMIT_COUNT}" > /app/VERSION \
    && chown -R app:app /app

ENV XSD_DIR=/app/XSD
ENV PORT=8080
ENV PATH="/app/.venv/bin:$PATH"
ENV MAX_XML_BYTES=10485760
# Quiet Python / fewer writes on cold start
ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1

USER app

EXPOSE 8080

# 1 worker = lower memory + simpler cold start; threads handle concurrent Dash requests.
# XSD index is lazy (first validate), so listening starts quickly.
CMD ["sh", "-c", "exec gunicorn \
  --bind 0.0.0.0:${PORT:-8080} \
  --workers 1 \
  --threads 4 \
  --timeout 90 \
  --graceful-timeout 10 \
  --keep-alive 5 \
  --access-logfile - \
  --error-logfile - \
  --capture-output \
  app:server"]
