# Experiment specification

This package targets the numerical content of manuscript v0.19 and the retained archival companion analyses. The package runs in MATLAB; Python is not needed. Settings are executable in `prpaper_config.m`, `engines/revision/vendor/jog_config.m`, `jog_config_v2.m`, `engines/revision/pr_config.m`, and `engines/native/prnc_config.m`. Every fresh archive also saves its complete configuration. The manuscript identifiers use **E for Experiment**; archived J identifiers are preserved to maintain traceability.

## Identifier crosswalk and stages

| Manuscript | Archived identifier | Experiment | Numerical production stage |
|---|---|---|---|
| E01 | J09 | Reference camera, noise, depth, control-count and global-translation conditions | `base`, `base_analysis` |
| E02 | J10 | Paired noise-scale sweeps on four fixed geometries | `base`, `base_analysis`; `bias` and `reparameterization` add diagnostics |
| E03 | J11 | Shared-covariance misspecification | `base`, `base_analysis` |
| E04 | J12 | Independently sampled control-geometry population | `base`, `base_analysis`; `native` extends coordinate comparison |
| E05 | J13 | Shared similarity perturbations | `base`, `base_analysis`; `rotation` adds selected stronger rotations |
| E06 | J14 | Local, patch and global source-strength comparisons | `base`, `base_analysis` |
| E07 | J15 | Propagation to exact independent plane and image targets | `base_analysis` and `postprocess` |
| Supporting analytical verification | J00–J08 | Algebraic identities, linear Gaussian and reduced-camera experiments | `base`, `base_figures` |

The archive code retains J00–J15 rather than renaming stored keys. E01–E07 are labels for readers. J00–J08 are implementation/analytical verification stages and do not shift E01 to E10. S denotes a Supporting Information section, figure or table, not another simulation module.

## Stochastic assumptions and units

* A single 10-parameter camera is estimated: 3 position, 3 rotation, log focal length, radial distortion, and 2 principal-point coordinates.
* Camera position is `[2; -1; 1.5]` m; rotation vector is `[0.15; -0.10; 0.05]` radians; focal length is 3,500 pixels; principal point is `[25; -15]` pixels; radial parameter is −0.08.
* Image width/height are 6,000/4,000 pixels and image normalisation scale is 3,000 pixels. Mean control depth is 20 m and image occupancy is 0.75.
* Local image STD is 0.5 pixels; local object-coordinate STD is 0.02 m; patch STD is 0.02 m. The reference global-translation STD, when that component is selected, is 0.05 m. Anisotropy multiplier is 1.
* A depth spread δ is the **dimensionless full depth width divided by 20 m**, not a metric STD: δ = 0.02 means a 0.4 m full depth interval.
* The noise multiplier ε multiplies all selected local/shared STDs together. Covariances therefore scale by ε². The E03 α multiplier acts on shared **variance**, not STD.
* Observed-DLT multistart is used for the practical camera fits; radial starting values are −0.15, 0, +0.15. Truth-local starts are restricted to the deterministic bias diagnostic.
* Shared similarity noise is an **additive first-order loading** of Gaussian perturbations. It is not an exact finite rigid/similarity transformation experiment.
* Exact external planes and checkpoints define camera-only target propagation. Target coverage is pointwise 2-D coverage; it is not simultaneous coverage of all 25 target points.

## Paper profile

### Core Monte Carlo sizes and seeds

| Quantity | Paper value |
|---|---:|
| Linear Gaussian Monte Carlo count | 5,000 |
| Reduced-plane Monte Carlo count | 3,000 |
| Camera fits per fixed condition | 2,000 |
| Algebraic identity cases | 200 |
| E04 independent geometries per regime | 20 |
| E04 maps per geometry | 200 |
| Camera batch size | 25 |
| Nominal coverage grid | 0.50, 0.80, 0.90, 0.95, 0.99 |
| Original master seed | 2,009,162,026 |
| Revision seed | 3,009,162,028 |
| Original analysis seed | 3,009,162,029 |
| Conditional-Gaussian diagnostic seed | 22,092,026 |
| Conditional-Gaussian draws | 1,000,000, in chunks of 50,000 |
| Paired descriptive-curvature bootstrap seed | 9,003 |
| Geometry/bootstrap replicates | 2,000 |

The revision generator uses `mrg32k3a` with `NormalTransform='Inversion'` and deterministic substreams indexed by suite, geometry, coupling, trial and role. This preserves pairing across intended noise/covariance variants. Do not replace a seed or substream scheme to obtain more favourable coverage. MATLAB's descriptive bootstrap is fully reproducible within this package; it need not reproduce the old Python RNG's bootstrap resampling indices.

### E01–E06 grids

* **E01/J09:** baseline n = 30, δ = 0.15; ε = 0.1, 0.3, 1, 2; depth widths δ = 0.02, 0.05, 0.15, 0.30; point counts n = 13, 30, 60. Baseline duplicates are omitted. The global-translation family uses all three point counts. These reference geometries are distinct from E02 geometries.
* **E02/J10:** four regimes `(n, δ) = (30,0.15), (30,0.05), (30,0.02), (13,0.15)`; ε = 0.03, 0.1, 0.3, 1, 2 on fixed paired geometry. There are 20 conditions.
* **E03/J11:** M1 shared-variance factors α = 0.25, 0.5, 1, 2, 4, plus GH local, marginal-diagonal and fixed-3D WLS comparisons. M4 compares correct patch+global covariance, omitted global, omitted patch and GH local. Optional M2/M3/M5 extensions are not enabled in the manuscript configuration.
* **E04/J12:** the same four `(n,δ)` regimes as E02, each with 20 independent geometries and 200 maps per geometry; all 80 geometries are included.
* **E05/J13:** n = 13, 30, 60; shared rotation STDs 0.005° and 0.01°; shared translation STD 0.02 m; shared scale STD 20 ppm. The pivot-shift diagnostic uses `[20;0;0]` m. The selected `rotation` extension repeats the three point counts at 0.05° and 0.1° with 2,000 maps per condition and GH local/GH full.
* **E06/J14:** `(local XYZ STD, patch STD, global STD)` in metres: `(0.02,0.02,0)`, `(0.005,0.02,0)`, `(0.005,0.03,0.03)`.

The main methods are fixed-3D WLS, GH local, GH marginal-diagonal, and GH full. The covariance-misspecification experiment has its own explicitly labelled covariance variants. Reported covariance is not multiplied by an estimated residual variance factor.

### E07 targets and postprocessing

The original target grid has 5×5 points at 20 m, with half-width fraction 0.25. The PR `postprocess` extension evaluates reference, narrow-reference and global n = 60 conditions at depths 10, 20 and 40 m. Oblique planes have 60°/75° tilts at 20 m, with half-width fraction 0.10. The target grid is 5×5 in each case. Finite camera-derived errors determine RMSE; valid propagated covariance determines conditional coverage; operational coverage counts failed fits/targets as misses. Undefined truth targets remain NaN.

The `bias` stage uses all four E02 geometries, ε = 0.1, 0.3, 1, and directional steps 0.02, 0.01, 0.005. It evaluates all covariance-factor directions in the paper profile. Solver step/constraint tolerances tighten to 1e-10/1e-11 for this deterministic diagnostic. A partial directional trace is recorded as incomplete and must not be interpreted as a full Hessian trace.

The `reparameterization` stage refits the same 2,000 narrow noise-sweep observations at n = 30, δ = 0.02, ε = 1 with direct focal coordinates and the same observed-data initializer pool. Its original common-chart results are retained. The unified collector computes **native** direct-focal errors and transforms the full covariance, including cross-covariances, at each estimate. These are parameterisation-sensitive local Wald regions, not invariant confidence sets.

The `native` stage performs no new fits: it processes saved reference, narrow reference, narrow noise sweep, omitted-global and global n = 60 conditions, and all 20 geometries in each of the four population regimes. A reference 2-D display uses mean covariance and a Schur-complement joint slice; it is never substituted for a trial-specific 10-D inclusion test.

### Solver constraints

Ordinary camera fitting uses at most 100 iterations and 18 line-search steps; step tolerance 2e-8, constraint tolerance 2e-9, and rank tolerance 1e-10. Allowed focal range is 300–30,000 pixels; radial range is −0.8–0.8; absolute principal-point bound is 6,000 pixels. Parameter scales are `[20,20,20,1,1,1,1,1,3000,3000]`. The output retains fit validity and operational as well as conditional coverage.

## Reduced profiles

| Setting | Smoke | Pilot | Paper |
|---|---:|---:|---:|
| Original master seed | 9,162,026 | 1,009,162,026 | 2,009,162,026 |
| Revision seed | 3,009,162,026 | 3,009,162,027 | 3,009,162,028 |
| Linear / reduced-plane maps | 80 / 80 | 1,000 / 1,000 | 5,000 / 3,000 |
| Camera maps per fixed condition | 3 | 100 | 2,000 |
| Identity cases | 10 | 50 | 200 |
| E04 geometries × maps | 2 × 3 | 5 × 50 | 20 × 200 |
| Strong-rotation maps | 3 | 100 | 2,000 |
| Focal-coordinate refits | 3 | 100 | 2,000 |
| Conditional-Gaussian draws | 10,000 | 100,000 | 1,000,000 |
| PR source batches per selected condition | 1 | 4 | All |
| PNG resolution | 120 dpi | 300 dpi | 600 dpi |

Smoke restricts the strong-rotation extension to 0.05°, n = 13; the bias check to geometry 1, two step sizes and three directions; and native population processing to one geometry and one batch per condition. Such products test the processing path and cannot support manuscript conclusions. Smoke and pilot explicitly remain `paper_ready=false`.

## Figure production and stage timing

The final `figures` stage creates **main Figures 2–6 and companion Figures S1–S13**, using only the collected data and derived analysis. Every figure receives PNG, editable MATLAB FIG, vector PDF, and a `_data.mat` payload; captions and a manifest identify sources. Figure data are also embedded in the unified `output.mat`. The original engine assets used by the publication adapter—F01, F02, F03, F04, F07, F08, F09, F10, F11, F12, F13 and F14—are retained under `raw/base/figures` as provenance/diagnostics. Other legacy plots, including the many F15 target panels, are not rendered by the unified pipeline; all computed raw observations, fits and target data remain preserved. Publication target figures use the extended PR target results.

| Publication figure | Required results |
|---|---|
| Main 1, workflow | Author-prepared; excluded from default code output |
| Main 2; S3 | Reduced-camera analytical/Monte Carlo verification |
| Main 3; S10 | E03 covariance omission and variance-scaling grids |
| Main 4 | E02 noise sweeps and E04 geometry population |
| Main 5; S13 | Narrow native focal-coordinate errors, full covariances and exact nonlinear mapping |
| Main 6; S9 | E07 PR target postprocessing |
| S1–S2 | Linear/analytical verification |
| S4; S12 | E05 original and stronger-rotation extension |
| S5 | E06 covariance sources |
| S6–S7; S11 | Camera NEES, fixed-design and residual diagnostics |
| S8 | Directional second-order bias diagnostic |

Stages have different cost: fresh camera fitting dominates; target propagation and Hessian directions also require substantial work. Reference mode performs neither new camera fitting nor new Monte Carlo observation generation. No fixed wall-clock guarantee is implied by the smoke/pilot/paper labels.

PNG export uses a temporary raster canvas no larger than 3,900 pixels per side to avoid an observed R2026a glyph-clipping issue. At 600 dpi this is at most 165.1 mm; no pixel resampling or font-size reduction is applied. Vector PDF/FIG retain their original publication dimensions.
