# ============================================
# Hanadiz Backend - Production Dockerfile
# ============================================

# Build Stage
FROM python:3.11-slim as builder

WORKDIR /app

# Install system dependencies for building
RUN apt-get update && apt-get install -y \
    gcc \
    g++ \
    make \
    libpq-dev \
    libssl-dev \
    libffi-dev \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Copy requirements
COPY requirements/base.txt requirements/base.txt
COPY requirements/production.txt requirements/production.txt

# Install Python dependencies
RUN pip install --no-cache-dir -r requirements/production.txt

# ============================================
# Production Stage
# ============================================
FROM python:3.11-slim

# Create non-root user
RUN groupadd -r hanadiz && useradd -r -g hanadiz hanadiz

# Install runtime dependencies
RUN apt-get update && apt-get install -y \
    libpq-dev \
    curl \
    postgresql-client \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Copy installed packages from builder
COPY --from=builder /usr/local/lib/python3.11/site-packages /usr/local/lib/python3.11/site-packages
COPY --from=builder /usr/local/bin /usr/local/bin

# Copy application code
COPY . .

# Create required directories
RUN mkdir -p /app/storage/logs \
    /app/storage/backups \
    /app/storage/cache \
    /app/storage/uploads \
    /app/storage/certificates \
    /app/storage/invoices \
    /app/storage/reports \
    && chown -R hanadiz:hanadiz /app

# Set ownership
RUN chown -R hanadiz:hanadiz /app

# Switch to non-root user
USER hanadiz

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=10s --retries=3 \
    CMD curl -f http://localhost:8000/health || exit 1

# Expose port
EXPOSE 8000

# Start command
CMD ["gunicorn", "-w", "4", "-k", "uvicorn.workers.UvicornWorker", "app.main:app", "--bind", "0.0.0.0:8000", "--timeout", "60", "--graceful-timeout", "30"]