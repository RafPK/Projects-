# Review Intelligence CSV Guide

The pipeline is designed to accept common review exports rather than requiring one exact source format.

## Recommended format

For the smoothest experience, use:

```csv
review,date,rating,product
"Excellent service and quick delivery",2026-01-02,5,Store A
"Shipping was late and support did not reply",2026-01-05,2,Store A
```

Only the review-text column is essential for NLP analysis. Date, rating, and product fields improve the Power BI experience.

## Common column names

The importer can recognize names such as:

| Purpose | Common names |
|---|---|
| Review text | `review`, `review_text`, `text`, `comment`, `feedback` |
| Rating | `rating`, `stars`, `star_rating`, `score` |
| Date | `date`, `created_at`, `timestamp`, `create_time` |
| Product/location | `product`, `business_name`, `store`, `location`, `restaurant`, `hotel`, `app` |

## One-command workflow

```bash
python scripts/update_dashboard.py data/raw/my_reviews.csv
```

For an unusual schema:

```bash
python scripts/update_dashboard.py reviews.csv \
  --review-column customer_comment \
  --date-column submitted_on \
  --rating-column score \
  --product-column store_name
```

After processing:

```text
Power BI Desktop → Home → Refresh
```

## Minimum viable CSV

A file with only review text can still be analyzed:

```csv
review
"Excellent service"
"Delivery took too long"
"The replacement process was easy"
```

Without date/rating/product fields, related dashboard filters and comparisons will naturally be limited.

## Data quality recommendations

For a stronger analysis:

- use at least a few hundred reviews when possible;
- keep the original review text intact;
- use a consistent rating scale;
- use parseable dates;
- avoid duplicate exports;
- include product/store/location fields when the business operates across multiple units.

## Privacy

Do not commit real customer review exports to this public repository.

For client work, use private/local storage or an approved secure environment. Remove or minimize unnecessary personal information before analysis, and agree on retention/deletion expectations with the customer.
