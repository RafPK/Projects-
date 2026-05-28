 Canada Jobs & Salaries Dashboard
An interactive data analysis and visualization dashboard exploring compensation trends, job market patterns, and salary drivers across roles, experience levels, and locations — with a focus on the Canadian tech and data science job market.
🚀 Live App
-------------------------------------------
Overview
This project answers a practical career question: what actually drives salary in the data and tech job market? Using real compensation data, it performs end-to-end EDA, statistical analysis, and interactive visualization to surface actionable insights for job seekers, hiring managers, and workforce analysts.
-------------------------------------------
Raw Compensation Dataset
(ai-jobs.net + Job Bank Canada)
        │
        ▼
  Data Ingestion & Loading
        │
        ▼
  Data Cleaning & Validation
  ├── Missing value handling
  ├── Outlier detection & treatment
  ├── Field standardization
  └── Duplicate removal
        │
        ▼
  SQL Querying & Aggregation
  (SQLite for structured extraction)
        │
        ▼
  Exploratory Data Analysis (EDA)
  ├── Distribution analysis
  ├── YoY trend analysis
  ├── Segment comparisons
  └── Correlation analysis
        │
        ▼
  Shiny Dashboard ~ AI assisted
  (interactive filters + visualizations)

-------------------------------------------
  Analysis Performed
Compensation Drivers

Identified key variables driving salary variation: role category, experience level, company size, remote work status, and geography
Applied statistical summarization to quantify the wage premium associated with each factor
-------------------------------------------
Trend Analysis

Year-over-year salary trends across job categories
Demand growth patterns by role type and location
Emerging vs. declining role segments in the Canadian market
-------------------------------------------
Segmentation

Salary distribution by experience level (entry / mid / senior / executive)
Cross-geography comparison: Canada vs. US vs. global remote
Role-level breakdowns: Data Scientist, Data Analyst, ML Engineer, Data Engineer

-------------------------------------------
Key Dashboard Features

Salary distribution explorer — filter by role, experience, location, and company size
YoY trend charts — track compensation changes over time by segment
Role comparison — side-by-side salary benchmarking across job titles
Geography heatmap — visualize compensation geography across regions
Pay disparity analysis — identify gaps across experience levels and categories
Dynamic SQL filtering — all views powered by live SQL queries against the underlying dataset
