# Epheo's Blog

This repository contains the source files for [blog.epheo.eu](https://blog.epheo.eu), a personal blog focusing on technical topics like OpenStack, OpenShift, and Linux.

## About

> "You can't unleash new things in closed sources"

This blog is built using [Sphinx](https://www.sphinx-doc.org/), a powerful documentation generator, with the [Furo](https://pradyunsg.me/furo/) theme for a clean, modern appearance.

## Getting Started

### Prerequisites

- Python 3.11+
- [UV](https://docs.astral.sh/uv/) for dependency management

### Setup

1. Clone this repository:
   ```bash
   git clone https://github.com/epheo/blog.git
   cd blog
   ```

2. Install dependencies using UV:
   ```bash
   uv sync
   ```

### Building the Blog

#### Using UV (Local Development)

To build the blog locally:

```bash
uv run make html
```

The generated HTML files will be available in the `_build/html/` directory. You can view them by opening `_build/html/index.html` in your web browser.

For a clean build:

```bash
make clean html
```

#### Using Podman/Docker (Containerized Build)

You can also build the blog using containers with Podman (or Docker). This ensures consistent builds across different environments and includes all necessary dependencies like Chrome for Mermaid diagram rendering.

**Build the container image:**
```bash
podman build -t sphinx-builder .
```

**Standard HTML build:**
```bash
podman run --rm -v $(pwd)/_build:/app/_build:Z sphinx-builder
```

**Clean build (removes existing build artifacts):**
```bash
podman run --rm -v $(pwd)/_build:/app/_build:Z sphinx-builder make clean html
```

**Check external links:**
```bash
podman run --rm -v $(pwd)/_build:/app/_build:Z sphinx-builder make linkcheck
```

**Development server with auto-rebuild:**
```bash
podman run --rm -p 8000:8000 -v $(pwd):/app:Z sphinx-builder sphinx-autobuild . _build/html --host 0.0.0.0 --port 8000
```

Then open your browser to `http://localhost:8000` to view the blog with automatic reloading on file changes.

> **Note:** The `:Z` flag in volume mounts is required for SELinux contexts on Fedora/RHEL systems. If you're not using SELinux, you can omit it.

## Project Structure

- `articles/`: Contains blog post content organized by topic
- `conf.py`: Sphinx configuration file
- `index.rst`: Main index file
- `_static/`: Static assets like images and CSS
- `_build/`: Generated output (not tracked in git)

## Writing Content

Blog posts are written in reStructuredText (`.rst`) or Markdown (`.md`) format. See the existing articles for examples of how to format your content.

## Contributing

Contributions are welcome! Please see [CONTRIBUTING.md](CONTRIBUTING.md) for details.

## License

This project is licensed under the GNU General Public License - see the [LICENSE](LICENSE) file for details.
