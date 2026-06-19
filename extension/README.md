# SciCheck browser extension

A minimal Manifest V3 extension: open it on any article page (PubMed, a journal,
a `doi.org` link…) and it shows that paper's SciCheck grade by calling your
SciCheck API.

## Configure

Edit [`config.js`](config.js) and set `SCICHECK_API_BASE` to your instance:

```js
window.SCICHECK_API_BASE = "http://localhost:3000"; // or https://your-app.onrender.com
```

The API endpoint it calls is `GET /api/v1/analysis?doi=<doi>` (CORS-enabled).

## Load it (unpacked — no store, no fee)

- **Chrome/Edge**: `chrome://extensions` → enable *Developer mode* → *Load unpacked* → select this `extension/` folder.
- **Firefox**: `about:debugging` → *This Firefox* → *Load Temporary Add-on* → select `manifest.json`.

## Publish (optional)

Firefox (AMO) and Edge are free; the Chrome Web Store charges a one-time $5
developer fee. No backend changes are needed — the extension only consumes the
public JSON API.

## How it works

1. On click, a small function is injected into the active tab to detect a DOI
   (citation meta tags → `doi.org` links → page URL → body text).
2. The popup calls the API; while the analysis runs in the background it polls
   every 2s, then renders the grade, score, per-criterion breakdown, and a link
   to the full analysis.
