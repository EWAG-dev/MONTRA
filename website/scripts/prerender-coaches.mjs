// Post-build SEO prerender. Generates a static, uniquely-optimized HTML page per
// approved coach at dist/coaches/<slug>/index.html (unique <title>, meta description,
// canonical, Open Graph, and JSON-LD Person schema, plus the coach name/tagline/bio
// baked into the static HTML), then writes sitemap.xml + robots.txt.
//
// The same client JS still hydrates the full interactive profile. Run after
// `vite build`:  node scripts/prerender-coaches.mjs
import { readFile, writeFile, mkdir } from 'node:fs/promises';
import { existsSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = dirname(fileURLToPath(import.meta.url));
const DIST = resolve(__dirname, '..', 'dist');
const BACKEND = process.env.BACKEND_URL || 'https://montra-production.up.railway.app';
const ORIGIN = (process.env.SITE_ORIGIN || 'https://montra-27532.web.app').replace(/\/$/, '');

const STATIC_PAGES = ['/', '/how-it-works.html', '/services.html', '/pricing.html', '/for-trainers.html', '/about.html'];

function esc(v) { return String(v ?? '').replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#039;' }[c])); }
function clip(v, n) { const s = String(v ?? '').replace(/\s+/g, ' ').trim(); return s.length > n ? s.slice(0, n - 1).trimEnd() + '…' : s; }

function cityRegion(locations) {
  const loc = (Array.isArray(locations) && locations[0]) || '';
  const [city = '', region = ''] = String(loc).split(',').map((p) => p.trim());
  return { city, region };
}

// Fill an empty `<tag id="X" ...></tag>` in the template with text content.
function fillById(html, id, text) {
  const re = new RegExp(`(<[a-z0-9]+[^>]*\\sid="${id}"[^>]*>)(</[a-z0-9]+>)`, 'i');
  return html.replace(re, `$1${esc(text)}$2`);
}

function seoHead(coach) {
  const { city, region } = cityRegion(coach.locations);
  const where = city ? ` in ${city}${region ? ', ' + region : ''}` : '';
  const title = `${coach.name} — In-Home Personal Trainer${city ? ' in ' + city : ''} | Elite Home Fitness`;
  const specialties = Array.isArray(coach.specialties) && coach.specialties.length ? coach.specialties.slice(0, 3).join(', ') : 'personal training';
  const desc = clip(`${coach.name} is a verified in-home personal trainer${where}, specializing in ${specialties}. Book a free consultation with Elite Home Fitness — powered by MONTRA.`, 158);
  const url = `${ORIGIN}/coaches/${coach.slug}`;

  const jsonLd = {
    '@context': 'https://schema.org',
    '@type': 'Person',
    name: coach.name,
    jobTitle: 'Personal Trainer',
    description: clip(coach.bio || desc, 300),
    url,
    worksFor: { '@type': 'Organization', name: 'Elite Home Fitness', url: ORIGIN },
    ...(city ? { areaServed: { '@type': 'City', name: city }, address: { '@type': 'PostalAddress', addressLocality: city, ...(region ? { addressRegion: region } : {}) } } : {}),
    ...(Number(coach.reviewCount) > 0 ? { aggregateRating: { '@type': 'AggregateRating', ratingValue: Number(coach.rating).toFixed(1), reviewCount: Number(coach.reviewCount) } } : {}),
  };

  return `
    <meta name="description" content="${esc(desc)}"/>
    <link rel="canonical" href="${esc(url)}"/>
    <meta property="og:type" content="profile"/>
    <meta property="og:title" content="${esc(title)}"/>
    <meta property="og:description" content="${esc(desc)}"/>
    <meta property="og:url" content="${esc(url)}"/>
    <meta property="og:site_name" content="Elite Home Fitness"/>
    <meta name="twitter:card" content="summary"/>
    <meta name="twitter:title" content="${esc(title)}"/>
    <meta name="twitter:description" content="${esc(desc)}"/>
    <script type="application/ld+json">${JSON.stringify(jsonLd)}</script>
  </head>`;
}

async function main() {
  const templatePath = resolve(DIST, 'coach-profile.html');
  if (!existsSync(templatePath)) {
    console.error('dist/coach-profile.html not found — run `npm run build` first.');
    process.exit(1);
  }
  const template = await readFile(templatePath, 'utf8');

  let coaches = [];
  try {
    const res = await fetch(`${BACKEND}/api/trainers`, { headers: { Accept: 'application/json' } });
    const data = await res.json();
    coaches = (data.trainers || []).filter((t) => t && t.slug && t.status === 'approved' && t.isActive !== false);
  } catch (err) {
    console.error('Could not fetch coaches; skipping coach prerender:', err.message);
  }

  // De-dupe slugs (first wins, matching backend resolution).
  const seen = new Set();
  const unique = coaches.filter((c) => (seen.has(c.slug) ? false : seen.add(c.slug)));

  let written = 0;
  for (const coach of unique) {
    const { city } = cityRegion(coach.locations);
    let html = template
      .replace('<title>Coach Profile | Elite Home Fitness</title>', `<title>${esc(coach.name)} — In-Home Personal Trainer${city ? ' in ' + esc(city) : ''} | Elite Home Fitness</title>`)
      .replace('</head>', seoHead(coach));
    // Bake visible content into the static HTML (JS re-renders the same values).
    html = fillById(html, 'coach-name', coach.name);
    html = fillById(html, 'coach-tagline', city ? `In-Home Personal Trainer in ${city}` : 'In-Home Personal Trainer');
    if (coach.bio) html = fillById(html, 'coach-bio', clip(coach.bio, 280));

    const dir = resolve(DIST, 'coaches', coach.slug);
    await mkdir(dir, { recursive: true });
    await writeFile(resolve(dir, 'index.html'), html, 'utf8');
    written++;
  }

  // sitemap.xml
  const today = new Date().toISOString().slice(0, 10);
  const urls = [
    ...STATIC_PAGES.map((p) => ({ loc: ORIGIN + (p === '/' ? '/' : p), pri: p === '/' ? '1.0' : '0.7' })),
    ...unique.map((c) => ({ loc: `${ORIGIN}/coaches/${c.slug}`, pri: '0.8' })),
  ];
  const sitemap = `<?xml version="1.0" encoding="UTF-8"?>
<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
${urls.map((u) => `  <url><loc>${esc(u.loc)}</loc><lastmod>${today}</lastmod><priority>${u.pri}</priority></url>`).join('\n')}
</urlset>
`;
  await writeFile(resolve(DIST, 'sitemap.xml'), sitemap, 'utf8');

  // robots.txt
  await writeFile(resolve(DIST, 'robots.txt'), `User-agent: *\nAllow: /\n\nSitemap: ${ORIGIN}/sitemap.xml\n`, 'utf8');

  console.log(`Prerendered ${written} coach page(s); sitemap has ${urls.length} URLs. Origin: ${ORIGIN}`);
}

main().catch((e) => { console.error(e); process.exit(1); });
