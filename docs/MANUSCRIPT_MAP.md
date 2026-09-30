# Manuscript v0.19: numerical products and source map

This map covers **five numerical main figures (2–6), thirteen archival companion figures (S1–S13), five main tables and five archival companion tables**, and the unnumbered experiment crosswalk. `E01`–`E07` are manuscript Experiment identifiers; `J09`–`J15` are stable archive/code identifiers. Supplementary `S` numbers are not experiment identifiers. Legacy `J00`–`J08` are analytical or numerical verification modules.

`DATA` denotes the struct assembled by `prpaper_collect`. The reference replay reads a compact archive of the completed manuscript run. A fresh run assembles the same structure from its own stage outputs. Publication functions do not replace missing fresh results with reference values. Reference replay repeats MATLAB numerical postprocessing and export; it does not rerun camera fitting.

## Figures

`prpaper_figures.m` creates each PNG, vector PDF, editable FIG, and matching `_data.mat`. The payload contains the plotted numerical arrays and complete plot objects' data. Array mappings below use MATLAB one-based panel indices. Original `Fxx` names are archived numeric plot payloads, not manuscript figure numbers.

| Manuscript item | Subject | Current MATLAB data source | Generating experiment/stage |
|---|---|---|---|
| Figure 1 | Author-prepared experimental workflow | Excluded by default | No numerical simulation result |
| Figure 2 | Reduced camera: point density, independent planes, depth diversity, global datum | `DATA.base.figure_data.F03.panels{3}`, `F04.panels{1,2}`, `F07.panels{1}` | Legacy reduced-camera verification J07/J08 and corresponding analytic payloads |
| Figure 3 | (a) Structural omission with patch+global error; (b) patch-only variance scaling | `prpaper_figure3.m` reads actual counts in `DATA.base.summaries`, J11c002 and J11c001 | E03/J11; Wilson intervals are recomputed |
| Figure 4 | Noise-scale and geometry-population coverage | `F08.panels{1,4}`, `F10.panels{1,3}` | E02/J10; E04/J12 |
| Figure 5 | Log/direct focal error displays and paired 10D tests | `DATA.focal` errors, per-fit full covariances, true rotation and fitted focal lengths | Narrow E02/J10 G3, epsilon=1; paired focal diagnostic |
| Figure 6 | Target RMSE/coverage with depth and tilt | `DATA.revision.postprocess.target_conditions{...}.targets{...}` | E07 target postprocessing of saved cameras |
| Figure S1 | Hidden shared modes and camera parameter blocks | `F01.panels{1,2}` | Analytical J01 |
| Figure S2 | Linear Gaussian verification | `F02.panels{1:4}` | Legacy linear covariance/residual verification |
| Figure S3 | Additional reduced-camera results | `F03.panels{3,4}`, `F04.panels{1,3}` | Legacy reduced-camera verification |
| Figure S4 | Shared similarity perturbations | `F13.panels{1:4}` | E05/J13 original rotation levels |
| Figure S5 | Covariance source contributions | `F14.panels{1:4}` | E06/J14 |
| Figure S6 | Full-camera NEES and marginal uncertainty | `F12.panels{1:4}` | Reference and narrow original camera diagnostics |
| Figure S7 | Gaussian, fixed-reference and fitted joint diagnostics | `DATA.revision.postprocess.diagnostics` | E01/E02/E03 diagnostic postprocessing |
| Figure S8 | Second-order bias component residuals | `DATA.revision.bias.geometries{...}.comparison` | E02 directional second differences |
| Figure S9 | Image-target errors and coverage | `DATA.revision.postprocess.target_conditions` image summaries | E07 image-target propagation |
| Figure S10 | Shared-variance scaling | `F09.panels{1,2}` | E03/J11 variance scaling |
| Figure S11 | Residual variance factors, rejection and coverage | `F11.panels{1:4}` | Original camera residual diagnostics |
| Figure S12 | Stronger rotations | `DATA.revision.rotation.conditions` | E05 extension, 0.05/0.1 degree |
| Figure S13 | Marginal outlines, joint slices and focal-axis extents | `DATA.focal`; recomputed mean-covariance Schur complements and exact exponential mapping | Narrow E02 focal diagnostic |

Figure 5 uses the arithmetic mean of each chart's **own** full fitted covariance for its illustrative 2D principal-axis display. Its panel (c) uses **per-fit** full 10D covariance and exact native focal errors. The colours are determined by the 10D log-focal test, not by distance to an illustrative circle. Figure S13 uses Schur complements of the arithmetic mean log covariance; it does not substitute the mean of per-fit Schur complements. The mapped log-focal boundary is sampled then transformed through the exponential map, not transformed by a linear Jacobian.

## Tables

`prpaper_tables.m` writes unrounded numeric CSV, formatted CSV, LaTeX snippets and `tables.mat`. Formatting follows v0.19 precision with decimal half-up rounding. Values are calculated from input data; manuscript numbers are used only as assertions in the archived-reference test.

| Manuscript item | Source and calculation | Output |
|---|---|---|
| Table 1 | `DATA.base.config`; actual target designs and stronger-rotation conditions | `Table1.csv` |
| Table 2 | E01/J09 condition 3: `method{...}.blocks.position/full`; empirical and mean reported covariance traces, native conditional coverage | `Table2.csv` |
| Table 3 | Recompute native Wald statistics in `DATA.native.records`; Gaussian/fixed-reference columns from `revision.postprocess.diagnostics`; `prnc.Reports.table4` | `Table3.csv` |
| Table 4 | Equal-weight geometry means and paired whole-geometry bootstrap from native records; `prnc.Reports.population` reproduces the original MATLAB bootstrap stream | `Table4.csv` |
| Table 5 | Pointwise min/max of GH-full RMSE/coverage and GH-local coverage across each target grid | `Table5.csv` |
| Table S1 | `DATA.legacy.J01.conditions`: `sqrt(trace(L*Sigma*L'))`, local-only counterpart and generalized directional variance inflation | `TableS1.csv` |
| Table S2 | E06/J14, GH-full covariance components: position-block traces divided by their sum | `TableS2.csv` |
| Table S3 | Finest-step second-order prediction and empirical bias whitened by each geometry's fixed unit-noise reference covariance; componentwise Monte Carlo SE comparison across paired noise levels | `TableS3.csv` |
| Table S4 | Native log/direct inclusion counts and Wilson intervals in the paired narrow focal diagnostic | `TableS4.csv` |
| Table S5 | Global 60 perpendicular target planes, fresh aggregation of pointwise reported/empirical covariance traces | `TableS5.csv` |
| Unnumbered E/J crosswalk | Stable one-to-one experiment mapping | `Experiment_crosswalk.csv` |

Table S5 reports the median local reported trace, median **pointwise** full-minus-local trace, and median **pointwise** empirical/local trace ratio over the grid. A median ratio must not be replaced by a ratio of medians. No independent table-aggregation script from the historical Python workflow is required: this calculation is included in `prpaper_analyze` and `prpaper_tables`.

Table 3 is conditional on covariance-valid fits; Table 4 is operational and counts failed fits as misses. Tables 3/4 were called Tables 4/5 in earlier manuscript/native-postprocessing packages. The archived engine naming is preserved, while publication file numbers follow v0.19.

## Additional numerical evidence

The following outputs preserve quantities stated in the prose and prevent rounding from hiding the underlying result:

- `All_condition_metrics.csv`: every retained condition/method/parameter block, empirical and predicted scatter, RMSE, conditional and operational coverage, mean NEES, residual variance factor and rejection rate.
- `All_native_conditions.csv`: each native-chart condition, valid/invalid counts, paired counts and differences, intervals and covariance-congruence checks.
- `All_target_pointwise.csv`, `All_target_ranges.csv`, `All_target_variance.csv`: every plane/image target point and corresponding grid ranges and covariance-trace summaries.
- `Fixed_metric_decomposition.csv`: full fixed-reference mean NEES, squared bias norm, centred scatter, independent covariance-trace check and exact focal-correction variance/cross terms.
- `Curvature_diagnostics.csv`: descriptive linear/quadratic fit coefficients, RMSE, R-squared and paired-bootstrap intervals.
- `Paired_chart_counts.csv`, `Display_summary.csv`: paired 10D classification counts, counts inside illustrative 2D outlines, clipped display points and typical physical error magnitudes.
- `Bias_comparison_by_noise.csv`: predicted/empirical bias and component SE residual for each geometry, noise level and parameter.
- `Strong_rotation.csv`: camera scatter, coverage and paired estimator differences for each extension condition.
- `analysis.mat`/unified `output.mat`: complete derived arrays, per-fit records, source metadata, covariance matrices and validation reports. Original stage outputs preserve fitted cameras and raw generated observations when a full simulation was run.

The fixed-metric identity uses population (1/N) centred scatter and must not be mixed with the unbiased sample covariance (1/(N-1)) used for empirical-scatter reporting. The reference condition gives approximately 118.24 in the log chart and 14.12 in the direct chart under corresponding fixed truth-tangent metrics. This is an algebraic comparison, not a new fitted covariance estimator or a parameterisation-invariant confidence-region benchmark.

The descriptive curvature bootstrap uses MATLAB `mt19937ar` with the explicit package seed. Its bootstrap interval is not bit-for-bit the historical NumPy `default_rng` interval; coefficients and deterministic fixed-metric results agree. The population-coverage bootstrap retains the original MATLAB `mrg32k3a` stream and geometry-level resampling and is reproducible at the archived precision. Tiny smoke samples have undefined curvature-bootstrap outputs; partial directional bias traces retain NaNs and `Complete_trace=false`.

## Original archive identities

- Base fitted-camera run: `run_c2835a74eff3`; source package JoG MATLAB v2.1, whose engine is preserved under `engines/revision/vendor`.
- Additional saved stage names: `postprocess_paper`, `bias_paper`, `rotation_paper`, `reparameterization_paper`, created by PR Revision MATLAB v1.
- Native-chart expansion: PR Native Chart Postprocess v1 `output.mat`, with records for reference, narrow, covariance-omission and geometry-population conditions.
- Historical `Figure6_data.mat` contains the paired narrow focal errors/covariances now used for manuscript Figure 5 and Supporting Information Figure S13. The historical filename is not a current manuscript figure number.

The compact reference fixture is numerical evidence for replay and verification. It is not presented as the entire raw observation archive. Fresh full execution regenerates observations, fits and checkpoints through the preserved engine and then creates all publication products from those new stage results.


## Added for manuscript v0.19

- `Fit_accounting_by_condition.csv`, `Fit_accounting_totals.csv`, `Invalid_fits_by_method.csv`: count each camera fit once from the position block. The original total is 102,000 condition–realisations × 4 plus 8,000 additional E03 variance-treatment fits = 416,000, of which 415,744 are valid. This excludes reduced/linear verification and subsequent PR refits.
- `Reduced_paired_diagnostics.csv`: all 27 J07/J08 reduced-camera conditions; sample scatter, limit, first-order finite-sample prediction and same-draw limiting/first-order comparisons.
- `Reduced_reconstruction_checks.csv`: reconstruct the saved estimator errors from its sufficient statistics, including guard decisions.
- `Reduced_condition_counts.csv`: count conditions below/above the limit, with explicit guard/fallback totals.
- `Reduced_bootstrap_MC.csv`: paired-row sample-SD bootstrap, 10,000 replicates, for J07c006 and J08c005. The retained resampling-count plan reproduces the historical NumPy PCG64 seed 20260925 draws exactly, while MATLAB recomputes every variance and quantile from the current data. This plan contains no observed values or result intervals. Smoke/pilot use an explicitly labelled MATLAB stream because their sample sizes differ. This bootstrap is distinct from the descriptive curvature bootstrap discussed above.
- `Reduced_depth_ratios.csv`: uniform-depth CV = δ/√12 and ratio 1 + 1/CV² at δ = 0.30, 0.15, 0.05 and 0.02.

Main figure captions follow the current v0.19 document. The numerical MATLAB renderings preserve results and panel content; they are not byte-identical copies of the manuscript's earlier plotting artwork. S-numbered products retain their archival identifiers for traceability, not a claim that a separate SI file must be submitted. The optional `include_workflow=true` schematic is a legacy convenience and is not the author's current Figure 1.
