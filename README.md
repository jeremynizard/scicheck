# SciCheck

A Rails web app that gives the general public a fast, transparent, **automated** read on the methodological quality of a scientific article — enter a DOI (or an article URL), get a 0–100 score (A–E) broken down across eight criteria.

> SciCheck is a critical-reading **aid**, not a verdict. Its indicators are automated and imperfect and do not replace expert peer review. See [docs/METHODOLOGY.md](docs/METHODOLOGY.md) for what each criterion does and does *not* measure.

## Stack

- **Ruby** 3.3.5, **Rails** 8.1 (importmap, Stimulus, Turbo — no React)
- **No database**: scores are computed on the fly and cached (Rails.cache). Results are addressable/shareable via a Post/Redirect/Get flow.
- External data: **Crossref**, **OpenAlex**, **PubMed E-utilities**, **PubPeer**.
- **Bilingual** (English default, French) — switch via the header or `?locale=fr`.

## Setup

```bash
bin/setup            # installs gems, starts the dev server
# or, manually:
bundle install
bin/rails server
```

Then open http://localhost:3000 and paste a DOI, e.g. `10.1097/MS9.0000000000003127`.

## Configuration (environment variables)

All optional, with sensible defaults — see [config/initializers/scicheck.rb](config/initializers/scicheck.rb).

| Variable | Default | Purpose |
|---|---|---|
| `SCICHECK_CONTACT_EMAIL` | `contact@scicheck.app` | Sent to Crossref/OpenAlex/NCBI "polite pools". Use a real, monitored address in production. |
| `NCBI_API_KEY` | _(none)_ | Raises PubMed rate limit from 3 to 10 req/s. |
| `SCICHECK_HOSTS` | _(none)_ | Comma-separated extra allowed Host headers (custom domains). `*.onrender.com` is always allowed. |
| `SCICHECK_ANALYSIS_CACHE_TTL` | `43200` (12 h) | How long a computed analysis stays cached. |
| `SCICHECK_HTTP_OPEN_TIMEOUT` / `SCICHECK_HTTP_READ_TIMEOUT` | `5` / `12` | Outbound HTTP timeouts (seconds). |

## Quality checks

```bash
bin/rails test          # full unit/integration suite (HTTP stubbed with WebMock)
bin/rubocop             # style (rails-omakase)
bin/brakeman --no-pager # static security analysis
bin/bundler-audit       # dependency CVE audit
```

CI (`.github/workflows/ci.yml`) runs all of the above on every PR.

To sanity-check the scorer against known articles (RCT, retracted, …) using the live APIs:

```bash
bin/rails scicheck:validate
```

## Architecture

```
AnalysesController  → thin: validates the DOI, runs (and caches) the analysis, PRG redirect to a shareable URL
DoiResolver         → normalizes raw DOIs / doi.org / publisher URLs (SSRF-guarded)
AnalysisRunner      → orchestrates two parallel waves of API calls, builds scores + meta
  HttpClient (concern) → timeouts, polite UA, uniform error handling, SSRF guard
  *Service classes  → one per API (Crossref, OpenAlex, PubMed, PubPeer, retractions, authors)
  Scoring::*        → one pure module per criterion
  Scoring::Aggregator → weighted average + renormalization, graded caps, coverage disclosure
```

See [docs/METHODOLOGY.md](docs/METHODOLOGY.md) for the scoring details and known limitations, and [docs/ROADMAP.md](docs/ROADMAP.md) for what's next.

## Deployment

Configured for [Render](https://render.com) via [render.yaml](render.yaml) (Docker). Set `RAILS_MASTER_KEY` and `SCICHECK_CONTACT_EMAIL` in the dashboard. The free plan uses ephemeral disk, so the analysis cache resets on restart — result URLs self-heal by recomputing on a cache miss.
