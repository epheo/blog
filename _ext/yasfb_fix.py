"""RSS feed fix for per-article index pages.

yasfb skips every page whose docname ends with ``index``, but our articles
live at ``articles/<slug>/index.rst``. This extension replaces yasfb's
``create_feed_item`` with a version that only skips the section-level index
pages listed in ``SKIP_PAGES``.

The replacement must happen *before* yasfb's ``setup()`` runs, because yasfb
connects ``create_feed_item`` to the ``html-page-context`` event by reference.
That is why ``conf.py`` loads this extension instead of ``yasfb`` directly,
and this module calls ``app.setup_extension('yasfb')`` after patching.

Written against yasfb 0.8.0 (pinned in pyproject.toml); revisit on upgrade.
"""

import yasfb

SKIP_PAGES = {'index', 'articles/index', 'notes/index', 'debug/index'}


def create_feed_item(app, pagename, templatename, ctx, doctree):
    if pagename in SKIP_PAGES:
        return
    env = app.builder.env
    metadata = env.metadata.get(pagename, {})
    pubdate = yasfb._get_last_updated(app, pagename)
    if not pubdate:
        return
    item = {
        'title': ctx.get('title'),
        'link': app.config.feed_base_url + '/' + ctx['current_page_name'] + ctx['file_suffix'],
        'description': yasfb._clean_feed_item_description(ctx.get('body')),
        'pubDate': pubdate,
    }
    if 'author' in metadata:
        item['author'] = metadata['author']
    env.feed_items[pagename] = item
    ctx['rss_link'] = app.config.feed_base_url + '/' + app.config.feed_filename


def setup(app):
    yasfb.create_feed_item = create_feed_item
    app.setup_extension('yasfb')
    return {'version': '1.0', 'parallel_read_safe': True}
