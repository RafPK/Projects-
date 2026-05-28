# 🌿 Bioplastic Film Flexibility — Experimental Design & ANOVA

A formal statistical study quantifying the effect of starch concentration and oil content on bioplastic film flexibility, using a two-factor completely randomized design (CRD), ANOVA, and a full residual diagnostic suite.

*STAT 403 — Simon Fraser University*

---

## Overview

This project addresses a practical materials science question: *which formulation inputs most affect the flexibility of bioplastic films?* Using rigorous experimental design and statistical inference, it identifies oil inclusion as the dominant driver of flexibility — delivering an evidence-based formulation recommendation within a $15 materials budget.

---

## Tech Stack

| Component | Tools |
|-----------|-------|
| Language | R |
| Statistical Modelling | `lm()`, `aov()` |
| Post-hoc Testing | `TukeyHSD()`, two-sample t-tests |
| Diagnostics | `shapiro.test()`, residual plots |
| Visualization | `ggplot2` |
| Reporting | R Markdown → PDF |

---

## Experimental Design

| Parameter | Value |
|-----------|-------|
| Design | Two-factor Completely Randomized Design (CRD) |
| Factor 1 | Starch concentration (low / high) |
| Factor 2 | Oil content (absent / present) |
| Sample size | n = 15 total observations |
| Replicates | n = 3 per treatment group |
| Response variable | Film flexibility (cm extension before fracture) |

### Power Analysis
- **Method:** t-test approximation for minimum detectable effect
- **Target:** Detect a 1 cm difference at σ = 0.22 cm
- **Result:** n = 3 per group achieves **>0.95 power**

---

## Key Results

| Source | F-statistic | p-value | Interpretation |
|--------|-------------|---------|----------------|
| Oil content | F(1,4) = 357 | < 0.001 | **Dominant driver** |
| Starch concentration | F(1,4) = 2.1 | 0.22 | Not significant |
| Interaction | F(1,4) = 0.8 | 0.41 | Not significant |

**Oil inclusion effect:** Mean flexibility increase of **3.33 cm** (95% CI: 2.84 – 3.82 cm)

### Residual Diagnostics
- **Normality:** Shapiro-Wilk p > 0.31 across all treatment groups ✅
- **Homoscedasticity:** Levene's test confirmed equal variance ✅
- **Diagnostic plots:** Residuals vs. fitted, Q-Q plot, scale-location, by-group boxplots

---

## Files

```
bioplastic_anova/
├── analysis.R          # Full R analysis script (power analysis, ANOVA, diagnostics)
├── report.Rmd          # R Markdown source for the formal report
├── report.pdf          # Compiled formal report
├── data/
│   └── bioplastic.csv  # Raw flexibility measurements
├── figures/
│   ├── boxplots.png    # By-group boxplots
│   ├── qqplot.png      # Q-Q normality plot
│   ├── residuals.png   # Residuals vs. fitted
│   └── interaction.png # Interaction plot
└── README.md
```

---

## Running the Analysis

```r
# Install dependencies
install.packages(c("ggplot2", "dplyr", "car", "emmeans"))

# Run full analysis
source("analysis.R")

# Compile report
rmarkdown::render("report.Rmd")
```

---

## Skills Demonstrated

- Experimental design: two-factor CRD with replication
- A priori power analysis for sample size determination
- One-way and two-way ANOVA with interaction testing
- Residual diagnostics: normality (Shapiro-Wilk), homoscedasticity (Levene's)
- Statistical inference and confidence interval interpretation
- Formal technical report writing (R Markdown → PDF)
- Translating statistical findings into actionable recommendations
