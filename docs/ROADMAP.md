# Roadmap

What this session delivered, and what is worth doing next.

## Done in the refactor

- **Security:** SSRF guard on user-supplied URLs (private/loopback/link-local/metadata IPs blocked, scheme allowlist, redirect re-checks, body cap); HTTP timeouts everywhere; TLS verification no longer weakened in production; rack-attack rate limiting; host authorization; dependency CVEs patched.
- **Robustness:** uniform `get_json` error handling (a flaky API degrades one criterion instead of 500-ing the request); every analysis thread is exception-guarded.
- **Methodology:** real study-design detection via PubMed MeSH publication types; multi-source open-science signals (registered data banks, COI statement, abstract); review duration from Crossref *or* PubMed; retracted-article hard cap; graded (not binary) PubPeer cap; neutral, non-defamatory journal-pedigree language; coverage disclosure on the result page.
- **Product:** Post/Redirect/Get + caching → shareable/bookmarkable result URLs, no re-POST on refresh, instant repeat lookups; authors matched to h-index by OpenAlex id (not by name).
- **i18n:** full English/French localization (locale files, `?locale=` switcher with session persistence + `Accept-Language` fallback). Default stays English; every user-facing string — views, flashes, and all scoring output — is translatable. An en/fr key-parity test guards against missing translations.
- **Validation harness:** `bin/rails scicheck:validate` scores a curated set of known DOIs (RCT, narrative review, retracted, …) against expectations — the groundwork for empirical calibration. Run manually (hits live APIs), not in CI.
- **Quality:** test suite (149 tests; scoring units + service parsing + SSRF + controller PRG + i18n parity + persistence + jobs + AI + API); CI now runs the suite.

## Done in the feature round

- **Persistence:** ActiveRecord enabled; durable analyses keyed by (DOI, locale) — SQLite dev/test, **PostgreSQL/Neon** in production. Shareable links survive restarts; history retained.
- **Background processing + polling:** `AnalysisJob` on ActiveJob `:async` (no Redis); the result page polls a `status` endpoint (Stimulus, `<noscript>` fallback) — first-time analyses no longer block a request.
- **AI-assisted layer (optional):** abstract-only summary + qualitative read in the user's language, via any OpenAI-compatible model (`LlmClient`, Groq default). Clearly labelled "experimental", **never affects the deterministic score**, hidden when no `LLM_API_KEY`.
- **Retraction Watch (CC0):** `RetractionWatchImporter` + `RetractedPaper`; flags retracted articles with the *reason* and cross-checks bibliographies offline. `rake scicheck:retraction_watch:import`.
- **Browser extension:** CORS-enabled JSON API (`/api/v1/analysis`) + Manifest V3 extension ([extension/](../extension/)) that scores the article on the page you're reading.

## Next, in rough priority order

### P1 — deeper AI extraction (the AI layer exists; make it structured)
- **Statistical reporting checks:** extract sample size, p-values, confidence intervals and pre-registration adherence as *structured* fields (needs full text — Europe PMC for OA articles).
- **Spin / overclaiming and COI-depth** as scored (not just displayed) signals, with calibration.

### P2 — coverage & fairness
- **Non-biomedical fields:** add arXiv/Semantic Scholar/OpenAlex topic-aware fallbacks so physics/CS/humanities aren't penalized by PubMed reliance.
- **Empirical calibration:** assemble a labeled corpus (retracted vs. high-quality vs. predatory) and tune weights/thresholds against it; report precision/recall (build on `scicheck:validate`).

### P3 — platform
- **Real-time progress** (Turbo Streams over ActionCable) — currently polling; would need Redis/Solid Cable.
- **Analytics dashboard** over the persisted history; scheduled Retraction Watch refresh.
