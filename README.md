# SciCheck

**A Nutri-Score for scientific papers.** Paste a DOI and get a single **A–E trust grade** — plus a per-criterion breakdown of *why* a study is, or isn't, trustworthy.

Most readers — students, clinicians and patients alike — can't quickly tell a rigorous study from a weak one. Existing tools either arrive too late (they only help once someone has already flagged your exact paper) or are built to help you read faster and trust the paper by default. SciCheck does the opposite: it surfaces the red flags **at the moment you're reading**.

> SciCheck is a critical-reading **aid**, not a verdict. Its indicators are automated and imperfect and do not replace expert peer review. See [docs/METHODOLOGY.md](docs/METHODOLOGY.md) for what each criterion does and does *not* measure.

## How it works

1. Paste a DOI (or a publisher URL). `DoiResolver` normalizes it (SSRF-guarded).
2. SciCheck fans out **in parallel** to public scholarly APIs — **Crossref, OpenAlex, PubPeer** — then a second wave to **PubMed** (real study design via MeSH), reference-retraction status, and author profiles.
3. **Eight weighted, fully deterministic criteria** are aggregated into a 0–100 score, an A–E grade, a color, and a plain-English summary.

| Criterion | Weight |
|---|---:|
| Study type (evidence pyramid) | 25% |
| Journal pedigree | 20% |
| Peer-review turnaround | 15% |
| Open-science signals | 10% |
| PubPeer flags | 10% |
| Citation profile | 8% |
| Retracted references in the bibliography | 7% |
| Author track record | 5% |

> **Graded caps:** PubPeer comments cap the score (1–2 → 74, 3+ → 59); a retracted article is hard-capped at 12 (grade E), whatever the rest of the score.

The scoring is **fully deterministic** — no LLM in the loop — so the same paper always gets the same grade, and every grade is explainable. The result page also discloses how many of the eight criteria actually had data ("coverage").

## Stack

- **Ruby** 3.3.5, **Rails** 8.1 (importmap, Stimulus, Turbo — no React)
- **Durable persistence**: results are stored per (DOI, locale) — SQLite in dev/test, **PostgreSQL in production** (Neon). Shareable/bookmarkable result URLs survive restarts.
- **Background analysis**: ActiveJob `:async` (in-process thread pool, no Redis); the result page polls for completion.
- **Optional AI layer**: a clearly-labelled, abstract-only summary + qualitative read via any OpenAI-compatible model (Groq by default) — never affects the deterministic score.
- External data: **Crossref**, **OpenAlex**, **PubMed E-utilities**, **PubPeer**, **Retraction Watch** (CC0).
- **American English** UI (built on Rails I18n, so another language can be re-added by dropping in a locale file).
- **JSON API** (`/api/v1/analysis`, CORS-enabled) consumed by a **Manifest V3 browser extension** ([extension/](extension/)).
- Dockerized; deployed on Render; GitHub Actions CI (tests, RuboCop, Brakeman, bundler-audit); PWA scaffolding.

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
| `DATABASE_URL` | _(SQLite in dev/test)_ | **Production** PostgreSQL connection (Neon). Required to boot in production. |
| `SCICHECK_CONTACT_EMAIL` | `contact@scicheck.app` | Sent to Crossref/OpenAlex/NCBI "polite pools". Use a real, monitored address in production. |
| `NCBI_API_KEY` | _(none)_ | Raises PubMed rate limit from 3 to 10 req/s. |
| `LLM_API_KEY` | _(none)_ | Enables the AI-assisted layer (OpenAI-compatible). Absent → the AI block is hidden. |
| `LLM_BASE_URL` / `LLM_MODEL` | Groq defaults | Swap LLM provider/model without code changes. |
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

To populate the Retraction Watch dataset (CC0) for richer retraction signals:

```bash
bin/rails scicheck:retraction_watch:import        # from Crossref Labs
bin/rails "scicheck:retraction_watch:import[path/to/retractions.csv]"  # from a local file
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

See [docs/METHODOLOGY.md](docs/METHODOLOGY.md) for the scoring details and candid known limitations, and [docs/ROADMAP.md](docs/ROADMAP.md) for what's next.

## Deployment

Configured for [Render](https://render.com) via [render.yaml](render.yaml) (Docker). Set `RAILS_MASTER_KEY` and `SCICHECK_CONTACT_EMAIL` in the dashboard. The free plan uses ephemeral disk, so the analysis cache resets on restart — result URLs self-heal by recomputing on a cache miss.

## Status

Working end-to-end MVP — **not yet launched publicly**. The eight deterministic criteria are fully implemented and tested, with durable persistence, background processing, an optional AI-assisted reading layer, Retraction Watch integration, and a browser extension. On the roadmap: deeper AI extraction (sample-size / p-value / spin), non-biomedical fallbacks, and empirical weight calibration.

---

A side project by [Jeremy Nizard](https://www.linkedin.com/in/jeremy-nizard/) — pharmacist (PharmD) and builder.
