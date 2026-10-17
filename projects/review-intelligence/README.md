# Review Intelligence

A customer review analytics project that transforms review CSV files into business-facing insights using Python, NLP, unsupervised learning, and Power BI.

> **Status:** Functional local MVP. The analytics pipeline and Power BI dashboard work end-to-end. The next milestone is a non-technical upload experience for customer datasets.

## What it does

Review Intelligence helps answer:

- What are customers most positive and negative about?
- Which recurring issues deserve attention first?
- Which topics are emerging across products, stores, or locations?
- How is sentiment changing over time?
- Which reviews best represent each discovered topic?

The current workflow accepts a review CSV, validates and cleans it, analyzes sentiment, discovers topics automatically, builds reporting tables, and refreshes an interactive Power BI report.

## Current workflow

```text
Review CSV
   ↓
Validation + cleaning
   ↓
Sentence embeddings
   ↓
UMAP dimensionality reduction
   ↓
HDBSCAN topic discovery
   ↓
Sentiment classification
   ↓
Topic and issue metrics
   ↓
Power BI star schema
   ↓
Interactive dashboard
```

## Technology

| Layer | Technology |
|---|---|
| Data processing | Python, pandas |
| Embeddings | Sentence Transformers |
| Topic discovery | UMAP, HDBSCAN |
| Sentiment | Transformer-based sentiment classification |
| Analytics | pandas, NumPy, scikit-learn |
| BI model | Star schema + DAX |
| Dashboard | Microsoft Power BI |
| Quality | pytest |

No generative AI is used by the deployed analysis pipeline or dashboard. The runtime uses deterministic preprocessing, embeddings, clustering, sentiment classification, statistical aggregation, and DAX measures.

## Use your own review CSV

The local MVP supports a one-command workflow:

```bash
python scripts/update_dashboard.py data/raw/my_reviews.csv
```

The importer detects common review, date, rating, and product column names. For unusual schemas, columns can be supplied explicitly.

Then refresh Power BI:

```text
Power BI Desktop → Home → Refresh
```

See [DATA_FORMAT.md](DATA_FORMAT.md) for CSV examples.

## Portfolio highlights

This project demonstrates:

- end-to-end NLP/ML pipeline development
- handling unknown CSV schemas
- reusable feature engineering and model outputs
- unsupervised topic discovery
- sentiment scoring and issue prioritization
- dimensional modeling for BI
- DAX measures and Power BI report development
- automated testing and regression fixes
- product thinking beyond a notebook

## Commercial direction

The current build is a working analytics engine and Power BI experience. Potential delivery models include:

- one-time customer review analysis
- recurring review monitoring
- private/local deployment for sensitive customer data
- consultant or agency analytics toolkit
- hosted web product with customer accounts and automated processing

See [COMMERCIAL.md](COMMERCIAL.md) and [ROADMAP.md](ROADMAP.md).

## Privacy

Do not commit customer review exports or confidential datasets to a public repository. Commercial deployments should keep customer datasets private and apply retention/deletion policies appropriate to the client.

## Request a demo or discuss a business use case

Open a GitHub issue using the Review Intelligence inquiry template. **Do not attach confidential customer data to a public issue.**

---

Built as an end-to-end data science and business intelligence portfolio project.
