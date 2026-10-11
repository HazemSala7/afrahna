# afrahna-web — the public website

A static Next.js site for **afrahna.co**, built from the same Laravel API the
app uses.

## Why static

Every page is rendered to HTML at build time and served as a file: opening the
site costs one request and paints without waiting on the API. That also means
it drops onto the same shared host the dashboard already lives on, with no Node
process to keep running.

- `/` home, `/vendors`, `/categories`, `/products`, `/offers`, `/reels`
- `/vendor/[name-id]` — one page per shop (~500), each with LocalBusiness
  structured data
- `/category/[name-id]`, `/city/[name-id]` — a real URL per filter, indexable
- `/search` — filters an index baked into the page; no request per keystroke
- `sitemap.xml`, `robots.txt`

## Commands

```bash
npm run dev        # localhost:3002
npm run typecheck
npm run export     # static export → out/
```

`npm run export` sets `NEXT_OUTPUT=export`. A plain `next build` does **not**
produce `out/` — it writes `.next` and the deploy would ship a stale export.

## Data

`src/lib/catalog.ts` pulls each collection **once per build** and indexes it by
vendor. Fetching per page instead meant ~2000 requests against an endpoint that
allows 240/minute: the first build collected a wall of 429s and shipped pages
whose sections were silently empty. Keep new pages reading from the catalogue.

## Deploying

```bash
npm run export                                  # → out/
../deploy/deploy-website.ps1 -DryRun            # see what would change
../deploy/deploy-website.ps1                    # upload
```

The site lives on **afrahna.ps**; the API, the uploads and the dashboard stay on
**afrahna.co**. `NEXT_PUBLIC_SITE_URL` (see `.env.production`) is what the
canonical links, the sitemap and the social cards use — change it there, not in
a dozen files.

### The host

The FTP account is chrooted to its own document root, so the remote path is
`/`, not `/public_html` (which is what the .co account uses). There is a
cPanel-generated `.htaccess` in that root setting the PHP handler: leave it.
The deploy is **upload-only** for that reason — `-Mirror` turns on remote
deletions, which is a decision about somebody else's files, not a default.

`ftp.afrahna.ps` did not resolve when this was first deployed, so the script
takes `-Server <ip>` to connect directly and skip DNS:

```bash
../deploy/deploy-website.ps1 -Server 65.181.113.236
```

Content changes when the site is rebuilt, so rebuild and upload after adding
shops or offers — a nightly job would keep it current on its own.
