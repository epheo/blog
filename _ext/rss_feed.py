"""RSS 2.0 feed generation, vendored replacement for yasfb 0.8.0.

Item selection follows yasfb (Apache 2.0, Doug Hellmann), trimmed to
what this site uses. yasfb skipped every docname ending in ``index``,
which dropped articles living at ``articles/<slug>/index.rst``; here
only the section indexes in SKIP_PAGES are excluded. Vendoring also
drops the pyquery dependency and yasfb's Sphinx version ceiling.
"""

import calendar
import email.utils
import re
import subprocess
import time
import xml.etree.ElementTree as ET

FEED_FILENAME = 'rss.xml'
SKIP_PAGES = {'index', 'articles/index', 'notes/index', 'debug/index'}


def _parse_pubdate(pubdate):
    for fmt in ('%Y-%m-%d %H:%M', '%Y-%m-%d'):
        try:
            return time.strptime(pubdate, fmt)
        except ValueError:
            continue
    return None


def _page_date(app, pagename):
    metadata = app.env.metadata.get(pagename, {})
    if 'Publish Date' in metadata:
        return _parse_pubdate(metadata['Publish Date'])
    # Undated pages fall back to their last git commit, which is what
    # puts notes and debug pages into the feed.
    try:
        stamp = subprocess.check_output(
            ['git', 'log', '-n1', '--format=%ad', '--date=short',
             '--', str(app.env.doc2path(pagename))],
        ).decode().strip()
    except subprocess.CalledProcessError:
        return None
    return _parse_pubdate(stamp)


def _clean_description(body):
    # The h1 duplicates the item title and headerlink anchors are
    # pointless outside the page.
    body = re.sub(r'<a class="headerlink".*?</a>', '', body)
    return re.sub(r'<h1.*?</h1>', '', body, flags=re.DOTALL)


def collect_item(app, pagename, templatename, context, doctree):
    context['metatags'] = context.get('metatags', '') + (
        '\n<link rel="alternate" type="application/rss+xml" '
        f'title="{app.config.project}" '
        f'href="{app.config.feed_base_url}/{FEED_FILENAME}" />')
    if pagename in SKIP_PAGES:
        return
    date = _page_date(app, pagename)
    if not date:
        return
    app.env.feed_items[pagename] = {
        'title': context.get('title'),
        'link': (app.config.feed_base_url + '/'
                 + context['current_page_name'] + context['file_suffix']),
        'description': _clean_description(context.get('body') or ''),
        'pubDate': date,
    }


def _rfc2822(date):
    # yasfb emitted no timezone at all, which RSS validators reject
    return email.utils.formatdate(calendar.timegm(date), usegmt=True)


def write_feed(app, exc):
    if exc or app.builder.name not in ('html', 'dirhtml'):
        return
    root = ET.Element('rss', {'version': '2.0'})
    channel = ET.SubElement(root, 'channel')
    for tag, value in (
        ('title', app.config.project),
        ('link', app.config.feed_base_url),
        ('description', app.config.feed_description),
        ('language', app.config.language),
        ('copyright', app.config.copyright),
    ):
        if value:
            ET.SubElement(channel, tag).text = value
    items = sorted(app.env.feed_items.values(),
                   key=lambda item: item['pubDate'], reverse=True)
    for item in items:
        element = ET.SubElement(channel, 'item')
        for tag in ('title', 'link', 'description'):
            ET.SubElement(element, tag).text = item[tag]
        ET.SubElement(element, 'pubDate').text = _rfc2822(item['pubDate'])
    path = app.builder.outdir / FEED_FILENAME
    with open(path, 'wb') as f:
        f.write(b'<?xml version="1.0" encoding="UTF-8" ?>\n')
        f.write(ET.tostring(root, encoding='utf-8', xml_declaration=False))


def init_feed(app):
    if not hasattr(app.env, 'feed_items'):
        app.env.feed_items = {}


def setup(app):
    app.add_config_value('feed_base_url', '', '')
    app.add_config_value('feed_description', '', '')
    app.add_config_value('feed_author', '', '')
    app.connect('builder-inited', init_feed)
    app.connect('html-page-context', collect_item)
    app.connect('build-finished', write_feed)
    return {'version': '1.0', 'parallel_read_safe': True}
