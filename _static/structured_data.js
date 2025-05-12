/**
 * Structured data for SEO
 * Adds JSON-LD schema markup for blog posts
 */
document.addEventListener('DOMContentLoaded', function() {
  // Check if this is an article page
  const articleInfo = document.querySelector('.article-info');
  
  if (articleInfo) {
    // Extract article metadata
    const title = document.title.split('—')[0].trim();
    const dateElement = document.querySelector('.article-info time');
    const date = dateElement ? dateElement.getAttribute('datetime') : null;
    const description = document.querySelector('meta[name="description"]')?.getAttribute('content');
    const authorName = 'Thibaut Lapierre';
    const logoUrl = window.location.origin + '/_static/logo.jpg';
    const pageUrl = window.location.href;
    
    // Create the JSON-LD structured data
    const articleSchema = {
      '@context': 'https://schema.org',
      '@type': 'TechArticle',
      'headline': title,
      'datePublished': date,
      'dateModified': date,
      'author': {
        '@type': 'Person',
        'name': authorName
      },
      'publisher': {
        '@type': 'Organization',
        'name': 'blog.epheo.eu',
        'logo': {
          '@type': 'ImageObject',
          'url': logoUrl
        }
      },
      'description': description,
      'url': pageUrl,
      'mainEntityOfPage': {
        '@type': 'WebPage',
        '@id': pageUrl
      }
    };
    
    // Add the structured data to the page
    const script = document.createElement('script');
    script.type = 'application/ld+json';
    script.text = JSON.stringify(articleSchema);
    document.head.appendChild(script);
  }

  // Add website schema
  const websiteSchema = {
    '@context': 'https://schema.org',
    '@type': 'WebSite',
    'name': 'blog.epheo.eu',
    'url': window.location.origin,
    'description': 'Personal how-to, technical notes and insights on OpenShift, OpenStack, Linux, and AI',
    'author': {
      '@type': 'Person',
      'name': 'Thibaut Lapierre'
    }
  };

  // Add the website structured data to the page
  const websiteScript = document.createElement('script');
  websiteScript.type = 'application/ld+json';
  websiteScript.text = JSON.stringify(websiteSchema);
  document.head.appendChild(websiteScript);
}); 