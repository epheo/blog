# Epheo's Blog

This repository contains the source files for [blog.epheo.eu](https://blog.epheo.eu), a personal blog by Thibaut Lapierre focusing on technical topics like OpenStack, OpenShift, and Linux.

## About

> "You can't unleash new things in closed sources"

This blog is built using [Sphinx](https://www.sphinx-doc.org/), a powerful documentation generator, with the [Furo](https://pradyunsg.me/furo/) theme for a clean, modern appearance.

## Getting Started

### Prerequisites

- Python 3.11+
- [Poetry](https://python-poetry.org/) for dependency management

### Setup

1. Clone this repository:
   ```bash
   git clone https://github.com/epheo/blog.git
   cd blog
   ```

2. Install dependencies using Poetry:
   ```bash
   poetry install --no-root
   ```

### Building the Blog

To build the blog locally:

```bash
poetry run make html
```

The generated HTML files will be available in the `_build/html/` directory. You can view them by opening `_build/html/index.html` in your web browser.

For a clean build:

```bash
make clean html
```

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
