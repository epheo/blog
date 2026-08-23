"""Head cleanups the stock extensions get wrong on their own.

- og:description: sphinxext-opengraph scrapes the page body, which
  starts with the article-info date and read time; prefer the curated
  ``.. meta:: :description:`` when the page has one.
- og:type stays "website" everywhere; dated pages are articles and
  deserve article:published_time.
- twitter:card so shares render a card outside the OpenGraph world.
- sphinxcontrib-mermaid 1.2 injects its CDN loader even when
  diagrams are pre-rendered to SVG; drop the useless module scripts.
"""

import re

from jsonld import _meta_description


def fix_head(app, pagename, templatename, context, doctree):
    metatags = context.get('metatags', '')
    description = _meta_description(metatags)
    if description:
        metatags = re.sub(
            r'(<meta property="og:description" content=")[^"]*(")',
            lambda m: m.group(1) + description + m.group(2),
            metatags)
    date = app.env.metadata.get(pagename, {}).get('Publish Date')
    if date:
        metatags = metatags.replace(
            '<meta property="og:type" content="website" />',
            '<meta property="og:type" content="article" />\n'
            f'<meta property="article:published_time" content="{date}" />')
    context['metatags'] = metatags + '\n<meta name="twitter:card" content="summary" />'
    context['script_files'] = [
        s for s in context.get('script_files', [])
        if 'mermaid' not in str(s) and 'd3.min.js' not in str(s)]


def setup(app):
    # after sphinxext-opengraph and sphinxcontrib-mermaid have run
    app.connect('html-page-context', fix_head, priority=800)
    return {'version': '1.0', 'parallel_read_safe': True}
