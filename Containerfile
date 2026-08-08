# Podman / Docker image — application only (no XSD schemas baked in).
# Mount host XSD/ at runtime: -v ./XSD:/app/XSD:ro
# syntax=docker/dockerfile:1
FROM ghcr.io/astral-sh/uv:python3.13-bookworm-slim

WORKDIR /app

COPY pyproject.toml uv.lock ./
RUN uv sync --frozen --no-dev

# App code + vendored UI assets (explicit — XSD excluded via .containerignore)
COPY app.py xsd.py ./
COPY assets ./assets
COPY examples ./examples

# Bake version for containers without .git (0.2.<commit count at build time)
ARG GIT_COMMIT_COUNT=0
RUN echo "0.2.${GIT_COMMIT_COUNT}" > /app/VERSION

# Mount point for host schema registry (populated at run time)
RUN mkdir -p /app/XSD
ENV XSD_DIR=/app/XSD
ENV PORT=8030
ENV PATH="/app/.venv/bin:$PATH"

EXPOSE 8030

CMD ["uv", "run", "python", "app.py"]
