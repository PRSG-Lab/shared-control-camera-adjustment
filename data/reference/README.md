# Compact retained reference data

Keep these four MAT files together:

| File | Variable | Contents |
|---|---|---|
| `reference_data.mat` | `DATA` | Original run configuration/condition indices; PR result summaries; all retained native-chart records; representative focal errors/covariances; analytic J01 data; source identity |
| `reference_base_summaries.mat` | `summaries` | The complete retained per-condition base summary structures |
| `reference_base_figure_data.mat` | `figure_data` | Numerical original-engine figure datasets |
| `reference_reduced_draws.mat` | `reduced` | All 27 J07/J08 conditions: saved effects, sufficient statistics, estimator errors, covariance predictions and guard decisions |

`prpaper_collect` merges the base summary/figure variables into `DATA.base` and loads the saved reduced-camera records into `DATA.reduced`. Splitting avoids the ordinary GitHub per-file size limit without discarding numerical fields. The pipeline identity checks the SHA-256 of all four files.

The files come from the completed run `run_c2835a74eff3` and its completed PR/native extensions. Private absolute source paths have been removed; run identifiers, original hashes, numerical values and configuration are preserved. The reference data contain no field observations or personally identifying measurement subjects.

This is the **figure/table reconstruction** dataset. It does not contain every original image/control noise draw, optimiser candidate and fit payload in the approximately 12.2 GB base archive. `RUN_PAPER` generates and retains the complete raw data in a new run folder. Never describe this compact reference alone as the complete raw-observation deposit.

The separate `data/resampling/reduced_bootstrap_counts.mat` stores the historical outcome-independent bootstrap row multiplicities. Its checksum is also part of run identity. It contains no camera observations or computed confidence intervals.
