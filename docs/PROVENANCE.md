# Numerical and code provenance

## Authoritative sources

The completed source run is `run_c2835a74eff3`, the paper-profile JoG **v2.1** archive generated on 2026-09-22. Its original final archive is 12,195,872,182 bytes and contains 123 nonlinear conditions, 102,000 condition–map evaluations and 416,000 camera fits (415,744 valid fits). These are archived production results, not claims about a production rerun during packaging.

The source engine is preserved under `engines/revision/vendor/`: the 43 MATLAB files match the source snapshots embedded in the original archive. The earlier folder named JoG_MATLAB_v2 is not the authoritative engine. Its flat-MAT implementation differs from v2.1, which stores checkpoint payloads as hashed byte records inside the final archive.

The author-supplied `PR_Revision_MATLAB_v1` contributes 17 MATLAB sources in addition to its 43-file embedded base engine. Its four completed paper-profile outputs are:

| Original result folder | Stage | Role |
|---|---|---|
| `postprocess_paper` | `postprocess` | Plane/image targets, fixed-Gaussian and joint diagnostics |
| `rotation_paper` | `rotation` | Six stronger shared-rotation conditions, 24,000 GH-local/GH-full fits |
| `bias_paper` | `bias` | Deterministic directional second-order bias on four geometries |
| `reparameterization_paper` | `reparameterization` | 2,000 direct-focal refits of retained observations |

The author-supplied `PR_Native_Chart_Postprocess_v1` contributes nine MATLAB sources. Its completed native-chart paper output processes 28,000 saved estimate–covariance pairs, including all 20 geometries per regime, without additional camera fits. Its original reference fixture is retained for the native-coordinate self-test.

Some older creation-time package manifests say that only smoke validation had been performed. The subsequently completed result archives, their completion flags and embedded source manifests take precedence when identifying the data used by the manuscript.

## What this integration changes

- Adds top-level entry points, stage locking/checkpoints, strict resume identities, a normalized collection schema and unified `output.mat`.
- Removes a hardcoded private source path from `engines/revision/+prrev/IO.m`; callers supply their own source path.
- Preserves the original numerical engines rather than silently changing the simulated measurement model, solver tolerances or random streams.
- Ports the former Python publication builders and saved-fit diagnostics to `src/prpaper_analyze.m`, `prpaper_tables.m` and `prpaper_figures.m`. Python is not a runtime dependency.
- Recomputes exact native focal errors, transforms all focal cross-covariances, distinguishes per-trial Wald tests from illustrative mean-covariance displays, and verifies Schur and fixed-metric identities.
- Reconstructs Supporting Information Table S5 from the saved per-target predicted and empirical covariance matrices. Previously exported summary values are comparison checks only.
- Excludes the author-prepared Figure 1 from default exports. Numerical figures are redrawn from data, without embedded manuscript screenshots.
- Keeps J09–J15 archive identifiers and exports E01–E07 manuscript labels. The code never relabels validation suites J00–J08 as primary experiments.

Current target: manuscript v0.19, SHA-256 `69ecf02c54140925fa250255aba415b381ae07a65027065bc7f88d75019fc087`. Its Tables 2–5 were re-extracted and compared with regenerated displayed numerical cells. Table 1 is generated from the executable configuration and includes explicit sample counts. Companion Tables S1–S5 retain previously verified archival definitions; no current separate SI document is needed for this package.

## Three reproducibility claims

1. **Stored numerical evidence:** the reference dataset derives from completed original/PR/native MAT archives and the retained representative focal arrays. Full original per-trial observations are not embedded in this compact dataset.
2. **Numerical and publication reconstruction:** reference mode recomputes the saved-fit diagnostics and table aggregations, then renders all figures. This path was exercised in MATLAB during packaging; see `validation/VALIDATION.md` for the final scope and metrics.
3. **Fresh simulation reproduction:** paper mode contains all code needed to create the observations, estimates, covariance matrices and extra experiments. A small fresh smoke profile exercises this path. The full production-size simulation is not claimed as rerun during packaging.

Fresh runs can differ in borderline optimiser success across operating systems/MATLAB versions. The original core generators and seeds are preserved. The descriptive curvature bootstrap now uses MATLAB `mt19937ar` seed 9003, rather than the old NumPy generator; its draws/interval endpoints are not claimed to be bitwise identical. This change does not alter the archived paired inclusion counts or deterministic regression coefficients.

The compact reference preserves the published summary arrays and representative individual records. New full runs save **all** generated records through the raw stage archives, plus the complete figures/tables and derived datasets in the unified MAT file. Keep the entire run directory when depositing complete data.

## Scientific interpretation retained

Native focal-coordinate comparisons concern parameterisation sensitivity of local Wald-type regions. They do not provide an invariant nonlinear confidence-region benchmark. Good target-level coverage is not evidence that every camera-parameter combination is well calibrated. Second-order bias and the coordinate-related scatter reduction do not constitute a complete higher-order covariance explanation. Optional advanced J16/profile/bootstrap code remains disabled by default and is not presented as an executed manuscript result.


## Version 1.1.0 verification and additions (2026-09-30)

The two final author-supplied branches were re-read from the supplied Matlab folder. All 43 shipped base-engine files match the code snapshots in the completed v2.1 source archive. The 17 revision and 9 native sources match their final supplied originals except the documented portable-path change in `+prrev/IO.m`. The earlier integrated v1.0.0 ZIP was used as the integration baseline, not as proof of current numerical validity.

The update adds the current two-panel Figure 3, excludes default Figure 1, includes the 27-condition reduced-model paired diagnostics and exact historical reduced-model bootstrap plan, and reports complete fit accounting. Core simulation/adjustment engines, their noise models, tolerances and original random streams are unchanged. Font and legend placement changes affect display only.

`reference_reduced_draws.mat` contains saved sufficient statistics read directly from the authoritative run: regional/global effects, local mean depth noise, lambda perturbations, observed means, errors, covariance predictions, guard results and seeds. `data/resampling/reduced_bootstrap_counts.mat` contains only random resampling multiplicities. It is independent of outcome values and is applied equally to fresh paper-sized data. Optional development fixture reconstruction is documented under `tools/`; the normal pipeline needs MATLAB only.
