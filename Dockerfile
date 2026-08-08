# Same as Containerfile (Docker default name).
# syntax=docker/dockerfile:1
FROM ghcr.io/astral-sh/uv:python3.13-bookworm-slim

WORKDIR /app

RUN groupadd --system app && useradd --system --gid app --home /app --shell /usr/sbin/nologin app

COPY pyproject.toml uv.lock ./
RUN uv sync --frozen --no-dev

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

USER app

EXPOSE 8080

CMD ["sh", "-c", "exec gunicorn --bind 0.0.0.0:${PORT:-8080} --workers 1 --threads 4 --timeout 120 --access-logfile - --error-logfile - app:server"]
