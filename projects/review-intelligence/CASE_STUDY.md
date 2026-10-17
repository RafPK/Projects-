# Case Study: Review Intelligence

## Problem

Customer reviews contain valuable operational signals, but raw review exports are difficult to summarize consistently. Simple averages hide the reasons customers are unhappy, while manual reading does not scale.

The goal of Review Intelligence was to build a reusable analytics pipeline that could take a review dataset and answer:

1. What topics are customers discussing?
2. How positive or negative is each topic?
3. Which issues should a business investigate first?
4. How do review patterns change over time?
5. Can an analyst move from raw CSV to an interactive BI report repeatably?

## Approach

The project was built in layers rather than as one notebook.

### Data foundation

The ingestion layer detects likely review/date/rating columns, validates them, removes unusable records and duplicates, and writes clean reusable data.

### Topic discovery

Sentence embeddings represent the semantic meaning of each review. UMAP reduces the embedding space and HDBSCAN discovers groups automatically, including noise points that do not fit a stable cluster.

This avoids requiring a fixed topic list before seeing the data.

### Sentiment

A transformer sentiment classifier produces probabilities and confidence rather than only a binary positive/negative label. Where star ratings exist, the pipeline can also identify disagreement between the written text and the numeric rating.

### Business metrics

The analysis combines topic prevalence and negative sentiment to prioritize issues rather than treating every cluster as equally important.

### Reporting

The final data is exported into a Power BI star schema and used across three report pages: Executive Overview, Topic Analysis, and Review Explorer.

## Result

The functional MVP supports a repeatable workflow from review CSV to an interactive Power BI dashboard. The project also includes automated tests and a one-command importer designed to reduce the friction of testing new datasets.

## Engineering decisions

### Why separate the ML and BI layers?

Power BI is used for presentation and slicing, while Python handles NLP and clustering. Keeping them separate prevents business-report logic from becoming tightly coupled to model implementation.

### Why unsupervised clustering?

The project is intended to work on unfamiliar datasets. Unsupervised topic discovery allows recurring issues to emerge from the reviews instead of requiring predefined categories.

### Why a star schema?

A fact/dimension model makes filtering by date, product, and topic easier to reason about and aligns the project with common BI practice.

## What the project demonstrates

- Python data engineering
- NLP feature generation
- unsupervised machine learning
- transformer-based sentiment analysis
- business metric design
- dimensional modeling
- Power BI/DAX
- testing and debugging
- productization thinking

## Next validation step

The strongest next case study is a larger, legally usable real-world review dataset. That would allow evaluation of topic stability, processing time, issue prioritization, and dashboard usefulness at a more realistic scale.
