# Multi-stage Dockerfile for Sphinx blog with static HTML output
# Stage 1: Build the blog HTML
# Stage 2: Serve static content with quay.io/epheo/kiss

# =============================================================================
# Stage 1: Builder - Build the blog HTML
# =============================================================================
FROM fedora:42 AS builder

# Install system dependencies for building
RUN dnf update -y && \
    dnf install -y \
        python3 \
        make \
        git \
        chromium-headless \
        nodejs \
        npm \
        uv \
        && dnf clean all

# Install Mermaid CLI globally
RUN npm install -g @mermaid-js/mermaid-cli

# Configure UV for optimal container builds  
ENV UV_COMPILE_BYTECODE=1 \
    UV_LINK_MODE=copy \
    UV_PROJECT_ENVIRONMENT=.venv

# Set working directory
WORKDIR /app

# Copy dependency files first (for better caching)
COPY pyproject.toml uv.lock ./

# Install dependencies only (not the project itself)
RUN uv sync --frozen --no-install-project

# Copy Mermaid and Puppeteer configuration files
COPY mermaid-config.json puppeteer-config.json ./

# Copy source code (do this last to maximize cache hits)
COPY . .

# Add virtual environment to PATH for build
ENV PATH="/app/.venv/bin:$PATH"

# Build the blog HTML
RUN make clean html

# =============================================================================
# Stage 2: Production - Static content with quay.io/epheo/kiss
# =============================================================================  
FROM quay.io/epheo/kiss:latest
COPY --from=builder /app/_build/html/ /content/