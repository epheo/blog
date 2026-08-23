"""Emit JSON-LD structured data at build time.

Replaces the former _static/structured_data.js: crawlers that skip JS
rendering never saw the injected schema, so bake it into the HTML head.
Pages with a ``:Publish Date:`` docinfo field get a TechArticle schema.
"""

import json
import re


def _meta_description(metatags):
    # docutils versions differ on attribute order in rendered meta tags
    for pattern in (r'name="description"[^>]*content="([^"]*)"',
                    r'content="([^"]*)"[^>]*name="description"'):
        match = re.search(pattern, metatags)
        if match:
            return match.group(1)
    return None


def add_jsonld(app, pagename, templatename, context, doctree):
    base = app.config.html_baseurl.rstrip('/')
    author = {'@type': 'Person', 'name': app.config.author}
    schemas = [{
        '@context': 'https://schema.org',
        '@type': 'WebSite',
        'name': app.config.project,
        'url': base + '/',
        'description': app.config.feed_description,
        'author': author,
    }]
    date = app.env.metadata.get(pagename, {}).get('Publish Date')
    if date:
        page_url = f'{base}/{pagename}{context.get("file_suffix", ".html")}'
        schemas.append({
            '@context': 'https://schema.org',
            '@type': 'TechArticle',
            'headline': context.get('title'),
            'datePublished': date,
            'dateModified': date,
            'author': author,
            'publisher': {
                '@type': 'Organization',
                'name': app.config.project,
                'logo': {
                    '@type': 'ImageObject',
                    'url': f'{base}/_static/logo.jpg',
                },
            },
            'description': _meta_description(context.get('metatags', '')),
            'url': page_url,
            'mainEntityOfPage': {'@type': 'WebPage', '@id': page_url},
        })
    context['metatags'] = context.get('metatags', '') + ''.join(
        f'<script type="application/ld+json">{json.dumps(s)}</script>'
        for s in schemas)


def setup(app):
    app.connect('html-page-context', add_jsonld)
    return {'version': '1.0', 'parallel_read_safe': True}
