# Scoring methodology

SciCheck combines **eight automated criteria** into a 0–100 score (A–E). Each criterion is a pure function in `app/services/scoring/`; the weighted aggregation lives in `Scoring::Aggregator`.

This document is deliberately candid about what each signal can and cannot establish. None of these criteria assesses whether an article's *findings are correct* — that requires reading it. They assess **proxies for methodological trustworthiness**.

## The criteria

| Key | Weight | Source(s) | What it measures | Levels |
|---|---|---|---|---|
| `study_type` | 25% | **PubMed publication types + MeSH headings**, OpenAlex/Crossref fallback | Position on the evidence-based-medicine pyramid (meta-analysis/SR → RCT → cohort → case report → preprint) | 0–5 |
| `review_pedigree` | 20% | OpenAlex source metadata (`is_core`, `is_in_doaj`, `indexed_in`) | Whether the journal is indexed in major databases | 0–3 |
| `review_process` | 15% | Crossref assertion dates, **PubMed history dates** | Submission→acceptance duration (a proxy for review depth) | 0–3 |
| `open_science` | 10% | **PubMed registered data banks + COI statement**, abstract text | Transparency / data-sharing / registration signals | 0–2 |
| `pubpeer` | 10% | PubPeer API | Post-publication comments (a flag for manual review) | 0–1 + graded cap |
| `citation_profile` | 8% | OpenAlex `cited_by_percentile_year` | Field- and year-normalized citation **attention** (not quality) | 0–3 |
| `retracted_references` | 7% | Crossref references → OpenAlex `is_retracted` | Whether cited sources have been retracted | 0–2 |
| `author_track_record` | 5% | OpenAlex Authors API (≤5 authors) | Max author h-index + institutional affiliation | 0–3 |

### Aggregation

- Each criterion is normalized to 0–100 (`level / max_level`), then weighted.
- **Renormalization:** criteria with no data (`level: nil`) are dropped and the remaining weights re-scaled. The result page **discloses coverage** ("Score computed from N of 8 criteria, X% of weight") so a score resting on a subset is never presented as if it were complete.
- **Graded caps** (applied after the average):
  - The analyzed article is itself **retracted** (OpenAlex `is_retracted`) → capped at **12** (grade E).
  - **PubPeer** comments: 1–2 → capped at 74; ≥3 → capped at 59.

## Why PubMed for study type

OpenAlex and Crossref only expose the *editorial* document type — `article`, `review`, `preprint`. That cannot distinguish a Cochrane systematic review from an opinion piece, or an RCT from a case series. PubMed's **MeSH Publication Types** carry the study *design* (`Randomized Controlled Trial`, `Meta-Analysis`, `Systematic Review`, `Case Reports`, …). We obtain the PMID from OpenAlex (`ids.pmid`) and read the design from PubMed `efetch`. This is the single biggest accuracy improvement over a type-label-only approach.

Observational designs (cohort, case-control, cross-sectional) are *not* publication types in PubMed — they are recorded as **MeSH subject headings** while the publication type stays the generic "Journal Article". So when the publication type is generic, we refine the design from the MeSH headings (`Cohort Studies` → cohort, `Case-Control Studies` → case-control, etc.). This is a heuristic — a methods paper *about* cohort studies could be mislabeled — and only runs as a fallback, never overriding a specific publication type.

## Known limitations (read this)

- **Biomedical bias.** Study-type detection, trial registration, and journal pedigree all lean on PubMed/MeSH. Non-biomedical fields (physics, CS, humanities) get the coarse OpenAlex/Crossref fallback and weaker signals.
- **Citations ≠ quality.** `citation_profile` measures attention; wrong or controversial papers are often highly cited, and good recent papers have not accrued citations yet (marked N/A in their first year).
- **h-index is a weak, biased proxy.** It favors senior researchers and large fields and is gameable. Hence its low (5%) weight.
- **Review duration is a coarse proxy** and is only available for the minority of publishers that deposit dates.
- **PubPeer exposes only a count, not comment content** via the public API — so we treat comments as a prompt to *read them*, not as proof of fault.
- **No calibration against ground truth.** The grade thresholds (A ≥ 80, B ≥ 60, …) and weights are expert-judgment defaults, not empirically validated against a labeled corpus. Treat the letter grade as a heuristic.
- **Open-science detection is still partial.** It does not read the full text, so a data-availability statement buried in the body (not the abstract, not a registered data bank) can be missed.

## Validation snapshot (live, 2026-06)

| DOI | Detected | Score |
|---|---|---|
| `10.1097/MS9.0000000000003127` | Narrative review (PubMed), 8/8 criteria | 80 (A) |
| `10.1056/NEJMoa2021436` (RECOVERY) | Randomized controlled trial (PubMed) | 88 (A) |
| `10.1016/S0140-6736(97)11096-0` (Wakefield, retracted) | Retracted → hard cap | 12 (E) |
