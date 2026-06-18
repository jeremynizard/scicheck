# SciCheck

**A Nutri-Score for scientific papers.** Paste a DOI and get a single **A–E trust grade** — plus a per-criterion breakdown of *why* a study is, or isn't, trustworthy.

Most readers — students, clinicians and patients alike — can't quickly tell a rigorous study from a weak or predatory-journal one. Existing tools either arrive too late (they only help once someone has already flagged your exact paper) or are built to help you read faster and trust the paper by default. SciCheck does the opposite: it surfaces the red flags **at the moment you're reading**.

## How it works

1. Paste a DOI (or a publisher URL). `DoiResolver` normalizes it.
2. SciCheck fans out **in parallel** to public scholarly APIs — **OpenAlex, Crossref, PubPeer** — then makes two dependent calls for reference retraction status and author profiles.
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

> **Hard rule:** any paper flagged on PubPeer is capped at grade **C**, whatever the rest of the score.

The scoring is **fully deterministic** — no LLM in the loop — so the same paper always gets the same grade, and every grade is explainable.

## Stack

Ruby on Rails 8 · Hotwire / Stimulus (importmap) · `concurrent-ruby` for parallel API fan-out · Dockerized · Kamal deploy · GitHub Actions CI (RuboCop, Brakeman, bundler-audit) · PWA scaffolding.

## Status

Working end-to-end MVP — **not yet launched publicly**. The eight deterministic criteria are fully implemented. On the roadmap: AI-assisted layers (abstract summarization, sample-size / p-value extraction, conflict-of-interest detection) and a browser extension.

---

A side project by [Jeremy Nizard](https://www.linkedin.com/in/jeremy-nizard/) — pharmacist (PharmD) and builder.
