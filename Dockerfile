# Same as Containerfile (Docker default name).
# syntax=docker/dockerfile:1
FROM ghcr.io/astral-sh/uv:python3.13-bookworm-slim

WORKDIR /app

COPY pyproject.toml uv.lock ./
RUN uv sync --frozen --no-dev

COPY app.py xsd.py ./
COPY assets ./assets
COPY examples ./examples
COPY XSD ./XSD

ARG GIT_COMMIT_COUNT=0
RUN echo "0.2.${GIT_COMMIT_COUNT}" > /app/VERSION

ENV XSD_DIR=/app/XSD
ENV PORT=8080
ENV PATH="/app/.venv/bin:$PATH"

EXPOSE 8080

CMD ["uv", "run", "python", "app.py"]
