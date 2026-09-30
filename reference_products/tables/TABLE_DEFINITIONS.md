# Generated table definitions

Table numbers match manuscript v0.19: Main Tables 1–5 and Supporting Information Tables S1–S5.

- Table 1: actual configuration; E means Experiment; archive J identifiers remain stable.
- Table 2: fixed reference control geometry; empirical scatter is sqrt(trace(sample covariance)); predicted scatter is sqrt(trace(mean reported covariance)).
- Table 3: trial-specific native Wald coverage; conditional on covariance-valid fits. Gaussian and fixed columns retain the log-focal metric.
- Table 4: equal-geometry operational coverage; failures are misses; paired whole-geometry bootstrap, seed 3009162029, 2000 replicates.
- Table 5: minimum–maximum over target grid points, camera-only uncertainty and exact planes/checkpoints.
- Table S1: fixed-geometry analytical covariance under nested parameter sets, legacy verification J01.
- Table S2: position covariance trace shares under the same GH-full estimator, not efficiency differences between estimators.
- Table S3: squared bias norms in fixed reference covariance; finest finite-difference step; maximum descriptive component SE residual over paired noise levels.
- Table S4: paired narrow-noise native coverage with Wilson intervals.
- Table S5: Global 60 perpendicular planes; median over target points of reported trace, pointwise full-minus-local trace, and empirical/local trace ratio. Ratios are medians of ratios, not ratios of medians.
- All numerical CSV values are unrounded. Formatted CSV/LaTeX use manuscript precision and decimal half-up rounding.
- Curvature bootstrap uses MATLAB mt19937ar, not the historical NumPy descriptive bootstrap generator.
- Plot reference outlines never classify individual trials; full per-trial covariance determines native coverage.
