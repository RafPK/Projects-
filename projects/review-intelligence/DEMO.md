# Review Intelligence Demo Guide

This guide is designed for portfolio reviews, interviews, and early customer conversations.

## 60-second version

1. Start on **Executive Overview**.
2. Explain that the dashboard is generated from a raw review CSV.
3. Point out review count, positive rate, negative rate, average rating, and topic count.
4. Show the issue-ranking chart and explain that the system combines topic prevalence with negative sentiment so the business can prioritize what to investigate.
5. Open **Topic Analysis** to compare discovered topics.
6. Open **Review Explorer** to show the underlying reviews behind the metrics.
7. Explain that a new CSV can be processed with one command and then refreshed in Power BI.

## Technical walkthrough

```text
CSV
 ↓
Schema detection
 ↓
Cleaning and validation
 ↓
Sentence embeddings
 ↓
UMAP
 ↓
HDBSCAN topic discovery
 ↓
Sentiment classification
 ↓
Topic and issue metrics
 ↓
Power BI star schema
 ↓
Dashboard
```

Key design decisions to mention:

- topic discovery is unsupervised, so the pipeline can work on unfamiliar datasets;
- sentiment and clustering are handled in Python rather than DAX;
- Power BI is used for interactive reporting, filtering, and business presentation;
- a star schema keeps date, product, and topic filtering predictable;
- automated tests protect the pipeline from regressions.

## Business walkthrough

Frame the project around decisions, not algorithms:

> "Instead of reading thousands of reviews manually, a business can use this dashboard to see which complaints are recurring, which topics have the highest negative impact, and which individual reviews explain those issues."

Useful examples:

- operations teams can identify recurring delivery or service problems;
- product teams can find reliability or usability complaints;
- multi-location businesses can compare stores or regions;
- customer-experience teams can track sentiment over time.

## Live-data demonstration

For a new CSV:

```bash
python scripts/update_dashboard.py data/raw/my_reviews.csv
```

Then:

```text
Power BI Desktop → Home → Refresh
```

For unusual columns, map them explicitly.

## What to say about the current product stage

Use clear wording:

> "The current version is a functional local MVP: the analytics pipeline and Power BI dashboard work end-to-end. The next product step is wrapping the same analytics engine in a simple customer-facing upload experience."

Do not describe the GitHub repository itself as a hosted SaaS. It is a portfolio and development repository.

## What not to share publicly

- customer review exports;
- API keys or credentials;
- proprietary client datasets;
- personally identifying information that is not needed for analysis;
- private Power BI tenant details.
