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
    'sphinx-jsonschema',   # Add JSON Schema support for structured data
    'sphinx.ext.autosectionlabel',  # For better cross-referencing
    'sphinx.ext.viewcode',  # For linking to source code
    'sphinx.ext.intersphinx',  # For linking to other documentation
    'sphinx_search.extension',  # Add enhanced search functionality
]

# Image settings for better optimization
imgmath_image_format = 'svg'  # Use SVG for math rendering if applicable
images_config = {
    'override_image_directive': True,
    'default_image_width': '100%',
    'responsive_images': True,  # Enable responsive images
    'lazy_loading': True,       # Enable lazy loading for images
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

# Sitemap configuration
sitemap_filename = "sitemap.xml"  # Ensure standard filename
sitemap_locales = [None]
sitemap_url_scheme = '{link}'
sitemap_add_html = True
sitemap_priority = {
    'index.html': 1.0,
    'articles/index.html': 0.9,
}
# Default priority for all pages not explicitly listed
sitemap_priority_default = 0.8
# Update frequency of pages
sitemap_changefreq = {
    'index.html': 'weekly',
    'articles/index.html': 'weekly',
}
sitemap_changefreq_default = 'monthly'

# OpenGraph and social media settings
ogp_site_url = "https://blog.epheo.eu/"
ogp_image = "_static/logo.jpg"
ogp_site_name = "epheo - personal how-to, technical notes and insights"
ogp_description_length = 300
ogp_type = "website"
ogp_custom_meta_tags = [
    '<meta name="viewport" content="width=device-width, initial-scale=1.0">',
    '<link rel="canonical" href="{{ pageurl }}">',
]

html_theme = 'furo'
html_static_path = ['_static']

# Add custom CSS
html_css_files = ['custom.css']

html_title = "epheo - personal how-to, technical notes and insights"
html_logo = "_static/logo.jpg"

html_extra_path = [ "_static/robots.txt", "_static/favicon.ico" ]

# Enable search functionality
html_search_language = 'en'
html_search_options = {
    'type': 'default'
}

html_theme_options = {
    "source_repository": "https://github.com/epheo/blog/",
    "source_branch": "main",
    "source_directory": "/",
    "footer_icons": [
        {
            "name": "GitHub",
            "url": "https://github.com/epheo",
            "html": """
                <svg stroke="currentColor" fill="currentColor" stroke-width="0" viewBox="0 0 16 16">
                    <path fill-rule="evenodd" d="M8 0C3.58 0 0 3.58 0 8c0 3.54 2.29 6.53 5.47 7.59.4.07.55-.17.55-.38 0-.19-.01-.82-.01-1.49-2.01.37-2.53-.49-2.69-.94-.09-.23-.48-.94-.82-1.13-.28-.15-.68-.52-.01-.53.63-.01 1.08.58 1.23.82.72 1.21 1.87.87 2.33.66.07-.52.28-.87.51-1.07-1.78-.2-3.64-.89-3.64-3.95 0-.87.31-1.59.82-2.15-.08-.2-.36-1.02.08-2.12 0 0 .67-.21 2.2.82.64-.18 1.32-.27 2-.27.68 0 1.36.09 2 .27 1.53-1.04 2.2-.82 2.2-.82.44 1.1.16 1.92.08 2.12.51.56.82 1.27.82 2.15 0 3.07-1.87 3.75-3.65 3.95.29.25.54.73.54 1.48 0 1.07-.01 1.93-.01 2.2 0 .21.15.46.55.38A8.013 8.013 0 0 0 16 8c0-4.42-3.58-8-8-8z"></path>
                </svg>
            """,
            "class": "",
        },
        {
            "name": "LinkedIn",
            "url": "https://linkedin.com/in/epheo/",
            "html": """
                <svg stroke="currentColor" fill="currentColor" stroke-width="0" viewBox="0 0 16 16">
                    <path d="M0 1.146C0 .513.526 0 1.175 0h13.65C15.474 0 16 .513 16 1.146v13.708c0 .633-.526 1.146-1.175 1.146H1.175C.526 16 0 15.487 0 14.854V1.146zm4.943 12.248V6.169H2.542v7.225h2.401zm-1.2-8.212c.837 0 1.358-.554 1.358-1.248-.015-.709-.52-1.248-1.342-1.248-.822 0-1.359.54-1.359 1.248 0 .694.521 1.248 1.327 1.248h.016zm4.908 8.212V9.359c0-.216.016-.432.08-.586.173-.431.568-.878 1.232-.878.869 0 1.216.662 1.216 1.634v3.865h2.401V9.25c0-2.22-1.184-3.252-2.764-3.252-1.274 0-1.845.7-2.165 1.193v.025h-.016a5.54 5.54 0 0 1 .016-.025V6.169h-2.4c.03.678 0 7.225 0 7.225h2.4z"></path>
                </svg>
            """,
            "class": "",
        },
    ],
    # Add search bar settings
    "light_css_variables": {
        "color-sidebar-search-background": "rgba(0, 0, 0, .05)",
        "color-sidebar-search-foreground": "var(--color-foreground-primary)",
    },
    "dark_css_variables": {
        "color-sidebar-search-background": "rgba(255, 255, 255, .05)",
        "color-sidebar-search-foreground": "var(--color-foreground-primary)",
    },
}

redirects = {
    "articles/openshift-ollama": "openshift-ollama/index.html",
}

# Enable JSON-LD structured data
html_js_files = ['structured_data.js']

# Intersphinx configuration
intersphinx_mapping = {
    'python': ('https://docs.python.org/3', None),
    'sphinx': ('https://www.sphinx-doc.org/en/master/', None),
}

# Autosection label settings
autosectionlabel_prefix_document = True
autosectionlabel_maxdepth = 2