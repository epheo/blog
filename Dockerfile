# Modern UV-based Dockerfile for Sphinx blog with Mermaid support
# Based on 2024/2025 UV + Docker best practices

# =============================================================================
# Stage 1: Builder - Install UV and dependencies
# =============================================================================
FROM fedora:latest AS builder

# Install system dependencies for building
RUN dnf update -y && \
    dnf install -y \
        python3 \
        python3-pip \
        python3-devel \
        gcc \
        gcc-c++ \
        make \
        git \
        chromium-headless \
        nodejs \
        npm \
        && dnf clean all

# Install Mermaid CLI globally
RUN npm install -g @mermaid-js/mermaid-cli

# Install UV
RUN pip3 install uv

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

# Copy source code and configuration files
COPY . .

# Copy Mermaid and Puppeteer configuration  
COPY mermaid-config.json puppeteer-config.json ./

# Set Chrome executable path for Puppeteer config
RUN sed -i 's|/usr/bin/google-chrome|/usr/bin/chromium-headless|g' puppeteer-config.json

# =============================================================================
# Stage 2: Production - Lean runtime with only necessary components
# =============================================================================  
FROM fedora:latest AS production

# Install minimal runtime dependencies
RUN dnf update -y && \
    dnf install -y \
        python3 \
        make \
        chromium-headless \
        nodejs \
        npm \
        && dnf clean all

# Install Mermaid CLI globally for runtime
RUN npm install -g @mermaid-js/mermaid-cli

# Create Chrome user for sandbox-less operation
RUN groupadd -r chrome && useradd -r -g chrome -G audio,video chrome \
    && mkdir -p /home/chrome/Downloads \
    && chown -R chrome:chrome /home/chrome

# Set working directory
WORKDIR /app

# Copy virtual environment from builder stage
COPY --from=builder /app/.venv /app/.venv

# Copy source code and configuration from builder stage  
COPY --from=builder /app /app

# Add virtual environment to PATH
ENV PATH="/app/.venv/bin:$PATH"

# Expose port for development server (sphinx-autobuild)
EXPOSE 8000

# Default command: build the blog using make
CMD ["make", "html"]

# Alternative commands available:
# - Clean build: podman run <image> make clean html  
# - Development server: podman run -p 8000:8000 <image> sphinx-autobuild . _build/html --host 0.0.0.0 --port 8000
# - Link check: podman run <image> make linkcheck