# Same definition as Containerfile (Podman uses Containerfile by default; Docker uses Dockerfile).
# XSD schemas are NOT in the image — mount ./XSD at /app/XSD.
# syntax=docker/dockerfile:1
FROM ghcr.io/astral-sh/uv:python3.13-bookworm-slim

WORKDIR /app

COPY pyproject.toml uv.lock ./
RUN uv sync --frozen --no-dev

COPY app.py xsd.py ./
COPY assets ./assets
COPY examples ./examples

ARG GIT_COMMIT_COUNT=0
RUN echo "0.2.${GIT_COMMIT_COUNT}" > /app/VERSION

RUN mkdir -p /app/XSD
ENV XSD_DIR=/app/XSD
ENV PORT=8030
ENV PATH="/app/.venv/bin:$PATH"

EXPOSE 8030

CMD ["uv", "run", "python", "app.py"]
