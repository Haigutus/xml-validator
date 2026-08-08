# syntax=docker/dockerfile:1
FROM ghcr.io/astral-sh/uv:python3.13-bookworm-slim

WORKDIR /app

# Install deps first (layer cache)
COPY pyproject.toml uv.lock* ./
RUN uv sync --frozen --no-dev || uv sync --no-dev

COPY . .

EXPOSE 8030
ENV PORT=8030
# Use the project venv created by uv
ENV PATH="/app/.venv/bin:$PATH"

CMD ["uv", "run", "python", "app.py"]
