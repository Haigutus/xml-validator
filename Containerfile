# syntax=docker/dockerfile:1
# App image with XSD schemas baked in (Cloud Run / free-tier friendly).
# Optional override at runtime: -v ./XSD:/app/XSD:ro  (host tree replaces baked /app/XSD)
FROM ghcr.io/astral-sh/uv:python3.13-bookworm-slim

WORKDIR /app

COPY pyproject.toml uv.lock ./
RUN uv sync --frozen --no-dev

COPY app.py xsd.py ./
COPY assets ./assets
COPY examples ./examples
# Schema registry — part of the image for Cloud Run / simple deploys
COPY XSD ./XSD

ARG GIT_COMMIT_COUNT=0
RUN echo "0.2.${GIT_COMMIT_COUNT}" > /app/VERSION

ENV XSD_DIR=/app/XSD
ENV PORT=8080
ENV PATH="/app/.venv/bin:$PATH"

# Cloud Run injects PORT (default 8080); local scripts can set 8030
EXPOSE 8080

CMD ["uv", "run", "python", "app.py"]
