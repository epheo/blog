# Configuration file for the Sphinx documentation builder.
#
# For the full list of built-in configuration values, see the documentation:
# https://www.sphinx-doc.org/en/master/usage/configuration.html

# -- Project information -----------------------------------------------------
# https://www.sphinx-doc.org/en/master/usage/configuration.html#project-information

project = 'blog.epheo.eu'
copyright = '2023, Thibaut Lapierre'
author = 'Thibaut Lapierre'

# -- General configuration ---------------------------------------------------
# https://www.sphinx-doc.org/en/master/usage/configuration.html#general-configuration

extensions = [ 'sphinx_design','sphinx_sitemap' ]

templates_path = ['_templates']
exclude_patterns = [
    '_build', 
    'Thumbs.db', 
    '.DS_Store',
    'Lib',
    'Scripts',
    'Include',
    '.venv',
]



# -- Options for HTML output -------------------------------------------------
# https://www.sphinx-doc.org/en/master/usage/configuration.html#options-for-html-output

html_baseurl = 'https://blog.epheo.eu/'
sitemap_locales = [None]
sitemap_url_scheme = '{link}'

html_theme = 'furo'
html_static_path = ['_static']

html_title = "epheo"
html_logo = "_static/logo.jpg"

html_extra_path = [ "robots.txt", "_static/favicon.ico" ]

html_theme_options = {
    "source_repository": "https://github.com/epheo/blog/",
    "source_branch": "main",
    "source_directory": "/",
}
