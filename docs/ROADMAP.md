# Roadmap

What this session delivered, and what is worth doing next.

## Done in the refactor

- **Security:** SSRF guard on user-supplied URLs (private/loopback/link-local/metadata IPs blocked, scheme allowlist, redirect re-checks, body cap); HTTP timeouts everywhere; TLS verification no longer weakened in production; rack-attack rate limiting; host authorization; dependency CVEs patched.
- **Robustness:** uniform `get_json` error handling (a flaky API degrades one criterion instead of 500-ing the request); every analysis thread is exception-guarded.
- **Methodology:** real study-design detection via PubMed MeSH publication types; multi-source open-science signals (registered data banks, COI statement, abstract); review duration from Crossref *or* PubMed; retracted-article hard cap; graded (not binary) PubPeer cap; neutral, non-defamatory journal-pedigree language; coverage disclosure on the result page.
- **Product:** Post/Redirect/Get + caching → shareable/bookmarkable result URLs, no re-POST on refresh, instant repeat lookups; authors matched to h-index by OpenAlex id (not by name).
- **i18n:** full English/French localization (locale files, `?locale=` switcher with session persistence + `Accept-Language` fallback). Default stays English; every user-facing string — views, flashes, and all scoring output — is translatable. An en/fr key-parity test guards against missing translations.
- **Validation harness:** `bin/rails scicheck:validate` scores a curated set of known DOIs (RCT, narrative review, retracted, …) against expectations — the groundwork for empirical calibration. Run manually (hits live APIs), not in CI.
- **Quality:** test suite (120 tests; scoring units + service parsing + SSRF + controller PRG + i18n parity); CI now runs the suite.

## Next, in rough priority order

### P1 — methodology depth (needs LLM or full text)
- **Statistical reporting checks:** extract sample size, p-values, confidence intervals, pre-registration adherence from full text (requires PDF/JATS full text + an LLM).
- **Conflict-of-interest & funding analysis:** parse COI/funding statements for undisclosed industry ties (PubMed exposes presence; depth needs NLP).
- **Spin / overclaiming detection** in abstract vs. results (LLM).
- **Retraction Watch integration** for richer retraction reasons than OpenAlex's `is_retracted` boolean.

### P2 — coverage & fairness
- **Non-biomedical fields:** add arXiv/Semantic Scholar/OpenAlex topic-aware fallbacks so physics/CS/humanities aren't penalized by PubMed reliance.
- **Empirical calibration:** assemble a labeled corpus (retracted vs. high-quality vs. predatory) and tune weights/thresholds against it; report precision/recall.

### P3 — platform
- **Persistence:** a real datastore (Postgres or SQLite + Solid Cache/Queue) for history, analytics, and a durable shareable-link store independent of the in-process cache.
- **Background processing:** move the multi-API fan-out to a job + Turbo Streams progress, so first-time analyses don't block a request thread.
- **Browser extension** that scores the article on the page you're reading.
