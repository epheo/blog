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

extensions = [ 
    'sphinx_design', 
    'sphinx_sitemap', 
    'sphinx_copybutton', 
    'sphinxext.opengraph',
    'sphinx.ext.imgmath',  # For optimizing math images if you have any
    'sphinx_reredirects',
]

# Image settings for better optimization
imgmath_image_format = 'svg'  # Use SVG for math rendering if applicable
images_config = {
    'override_image_directive': True,
    'default_image_width': '100%',
}

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

# OpenGraph and social media settings
ogp_site_url = "https://blog.epheo.eu/"
ogp_image = "_static/logo.jpg"
ogp_site_name = "epheo - personal how-to, technical notes and insights"
ogp_description_length = 300
ogp_type = "website"

html_theme = 'furo'
html_static_path = ['_static']

html_title = "epheo - personal how-to, technical notes and insights"
html_logo = "_static/logo.jpg"

html_extra_path = [ "robots.txt", "_static/favicon.ico" ]

html_theme_options = {
    "source_repository": "https://github.com/epheo/blog/",
    "source_branch": "main",
    "source_directory": "/",
}

redirects = {
    "articles/openshift-ollama": "openshift-ollama/index.html",
}