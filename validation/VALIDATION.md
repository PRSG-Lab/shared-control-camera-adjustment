# Release 1.1.0 validation — manuscript v0.19

Executed on 2026-09-30 using MATLAB R2026a Update 4, Apple silicon (MACA64). This report separates original production evidence, reference reconstruction and a newly executed small simulation. It does not claim a fresh production-size rerun.

## Authoritative original evidence

- Original completed JoG v2.1 run: `run_c2835a74eff3`.
- All 43 shipped base MATLAB sources match snapshots embedded in that run. The 17 revision and 9 native sources match the final supplied branches except the documented removal of a workstation path in `+prrev/IO.m`.
- Original 123 nonlinear conditions: 102,000 condition–realisations, 416,000 attempted fits, 415,744 valid and 256 invalid. The extra 8,000 above 102,000×4 arise from E03's additional variance treatments. Subsequent rotation/refit stages are excluded from this base total.
- Completed PR postprocess, rotation, bias, direct-focal refit and native-chart archives were inspected. These are historical completed outputs, not fresh fits made by the packaging process.

Evidence: `source_audit.json`, `authoritative_engine_comparison.json`, `supplied_source_comparison.json`; generated `Fit_accounting_*.csv` in `reference_products/tables/`.

## Current numerical checks

`RUN_VALIDATE` passed on the release source. Its `numerical_validation.json` records:

- Maximum camera A Jacobian discrepancy 1.2441533×10⁻¹⁰; B discrepancy 1.1199187×10⁻¹¹.
- GLS covariance relative discrepancy 6.5119591×10⁻¹⁴.
- Native coordinate congruence, focal cross-covariance, failed-fit denominator and finite focal-error identities passed.
- 2,000 retained paired cameras: 988 log-focal inclusions; 1,661 direct-focal inclusions. Paired cells: 984 both, 677 direct-only, 4 log-only, 335 neither.
- Fixed-reference centered scatter: 118.24262947687 (log focal), 14.12153501095 (direct focal).
- All 27 reduced-camera conditions reconstructed from saved sufficient statistics with maximum error difference 0, no guard fallbacks, 13 limiting-response sample SDs below the population limit and 14 above.
- J07c006 position sample SD 0.031921135904593 m; 10,000-bootstrap 95% interval 0.031124434511148–0.032694801846192 m. This reproduces the manuscript's displayed 0.03112–0.03269 m interval using its historical resampling plan.
- All 10 numbered tables and the seven-row E/J crosswalk were generated.

`manuscript_table_comparison.json` compares all **115 numerical cells** in current manuscript Tables 2–5 after removing whitespace only. All match their regenerated displayed values. Table 1 comes from configuration rather than verbatim copying its prose; companion S tables retain previously verified archival definitions. The current manuscript's SHA-256 and extracted cells are retained in `manuscript_tables.json`.

## Full reference reconstruction

`RUN_REFERENCE` completed all four publication stages from included numerical inputs: collect, analyze, tables and figures. It generated main Figures 2–6 and companion Figures S1–S13 (18 figures), each as PDF, PNG, FIG and numeric MAT. Main captions follow v0.19. Figure 1 is excluded by default. The ready-made `reference_products/` files are copied from this run.

Every PDF is a readable single page, every PNG was decoded and its dimensions/resolution checked, and every FIG/MAT pair exists. All PDFs were rendered for layout review; main and companion PNGs were also inspected. Font/legend adjustments affect artwork only. The MATLAB renderings reproduce numerical content rather than original image bytes. A completed-run resume reused all four stages without regeneration. See `reference_pipeline.json` and `figure_products.json`.

## Fresh simulation and checkpoint test

`tests/test_smoke_resume.m` exercises a fresh separate-seed smoke profile. It deliberately pauses after one base batch, resumes, checks the first checkpoint shard's timestamp/size remain unchanged, checks the public launcher path is restored, and confirms that changing the numerical seed is rejected for that destination. It then completes all 12 pipeline stages, including reduced-model analysis, target postprocessing, selected stronger rotation, partial directional bias, direct-focal refits, native-chart processing, tables and 18 figures.

The smoke base contains 51 nonlinear conditions, 153 condition–realisations and 624 valid fits out of 624. The deliberately small extension profiles do not constitute production evidence. Final assertions require `complete=true`, `paper_ready=false` and 18 figures. Machine-readable outcome: `smoke_test_report.json`.

## Validation limits

- The full 416,000-fit base simulation, complete 24,000-fit rotation extension and full directional bias trace were **not rerun in this release task**. `RUN_PAPER` supplies that path; the smoke profile tests its pipeline with reduced sizes.
- No real measurements, fixed-cloud conditional experiment, new control-selection experiment, invariant nonlinear region or additional advanced J16 experiment was introduced.
- Cross-platform/older-MATLAB execution and exact bitwise equality were not tested. Marginal optimiser outcomes can vary with numerical libraries.
- The distinct descriptive-curvature bootstrap uses the integration's declared MATLAB stream; it is not claimed to reproduce historical NumPy resampling draws. The reduced-model MC interval bootstrap and the population-coverage bootstrap retain their respective original plans/streams.
- The compact ZIP omits the original 12.2 GB raw base archive. It includes sufficient reference evidence for the supplied figures/tables and code that generates complete new raw archives. Preserve the whole fresh run folder for a full raw-data deposit.
- No upload, public repository release or DOI registration was performed.
