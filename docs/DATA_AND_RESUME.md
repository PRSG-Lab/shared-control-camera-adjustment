# Running, saving and resuming

Open the package folder in MATLAB and call `prpaper_setup`. The public launchers never search the user's Desktop, OneDrive or other cloud folders. Give an explicit source when reusing external results. A fast reproduction of the published products and an independent new Monte Carlo experiment are different operations.

## 1. Reproduce figures and tables from retained numerical evidence

```matlab
prpaper_setup;
file = RUN_REFERENCE(fullfile(pwd,'runs','reference_01'));
```

This reads `data/reference/reference_data.mat` and its three required companion files, `reference_base_summaries.mat`, `reference_base_figure_data.mat` and `reference_reduced_draws.mat`, and rebuilds the analysis, tables and 18 numerical figures (main Figures 2–6 and companion Figures S1–S13) with MATLAB. It does not use pre-rendered paper images. It does not claim to regenerate raw observations or perform fresh camera fitting. The compact reference file contains retained numerical evidence for the current manuscript.

## 2. Generate all simulations afresh

```matlab
file = RUN_SMOKE(fullfile(pwd,'runs','smoke_01'));
file = RUN_PAPER(fullfile(pwd,'runs','paper_01'));
```

Run only the command appropriate to the intended profile. A complete paper run can be very expensive. `RUN_PILOT` selects intermediate sample sizes. The profile-specific seeds are deliberate; smoke/pilot numerical estimates are not substitutes for the published experiment.

For a deliberate bounded run:

```matlab
file = RUN_PAPER(fullfile(pwd,'runs','paper_01'), 20);
% Later, with exactly the same code/settings:
file = RUN_RESUME(fullfile(pwd,'runs','paper_01'), 20);
% Finish without a new-task budget:
file = RUN_RESUME(fullfile(pwd,'runs','paper_01'));
```

The budget limits **new units in the active computational stage**: camera batches, completed original-analysis conditions, PR tasks, or native-chart batches. It is not a wall-clock timeout. J00–J08 verification, packing, figure generation, and an individual diagnostic task are not interrupted in the middle by this budget. A stage returns its checkpoint when the budget is reached; downstream stages do not run until it has actually completed. A final saved batch can require one subsequent resume call to finish aggregation.

## 3. Reuse explicit original and PR outputs

```matlab
opt = prpaper_config('paper');
opt.revision_root = '/path/to/PR_Revision_MATLAB_v1';
opt.native_file = '/path/to/native_chart_results/output.mat';
file = RUN_EXISTING('/path/to/original_v2_1/output.mat', ...
                    fullfile(pwd,'runs','existing_01'), opt);
```

The source must be the completed v2.1 archive, including completed original condition analysis and numeric figure data. Do not pass a legacy v2.0 flat archive or an incomplete checkpoint as `source_file`.

`revision_root` accepts an explicitly supplied PR package folder, its `results` folder, or a postprocess `output.mat`. The standard subfolder names are `postprocess_paper`, `rotation_paper` (also `strong_rotation_paper`), `bias_paper`, and `reparameterization_paper`. Existing stage outputs are checked against the original source run. Missing extensions are generated under the new destination. If only a postprocess MAT is supplied, the other extensions are computed afresh unless already present in the destination.

The original input and external completed PR/native archives are read-only. The pipeline neither relocates nor deletes them. Checkpoints store input locations so that resume can verify the same sources. Preserve these files or supply a complete fresh destination on relocation; do not edit checkpoint paths to bypass identity checks.

## 4. Run one stage, or regenerate presentation only

```matlab
opt = prpaper_config('paper');
RUN_STAGE('base', fullfile(pwd,'runs','paper_01'), opt);
% Finish the same run with all remaining stages:
RUN_PAPER(fullfile(pwd,'runs','paper_01'));
```

Supported stage names, in order:

1. `base`: original simulation and self-contained raw archive.
2. `base_analysis`: original condition summaries, diagnostics and E07 original targets.
3. `base_figures`: the 12 original numerical figure datasets consumed by the publication adapter (F01–F04, F07–F14), with diagnostic exports; redundant legacy F15 plots are not rendered and their computed target data are retained.
4. `postprocess`: extended target depths/tilts and conditional/joint diagnostics.
5. `rotation`: selected stronger shared-rotation fits.
6. `bias`: directional second-order bias diagnostic.
7. `reparameterization`: paired direct-focal refits.
8. `native`: native-chart comparison across reference and population conditions.
9. `collect`: normalised numerical data from the completed stages.
10. `analyze`: paired chart, target-variance and publication analysis.
11. `tables`: publication tables and numerical CSV exports.
12. `figures`: main and Supporting Information figures.

A stage-only command does not run prerequisites implicitly; they must exist or be supplied explicitly. It does not mark the full manuscript package complete.

To regenerate only the analysis/tables/figures from a unified output without any new fitting:

```matlab
RUN_FIGURES('/path/to/completed_run/output.mat', ...
            fullfile(pwd,'runs','presentation_02'));
```

Use a new destination for this operation. Publication PNGs default to 600 dpi for the paper profile. Direct lower-level `prpaper_figures` supports selected figure IDs; that convenience is separate from the full-package completion marker.

## 5. What is saved

A completed fresh run has the following structure (external-input runs can reference raw archives outside the destination):

```text
run/
  checkpoint.mat              Unified stage status and exact saved options
  output.mat                  Unified numeric evidence, analyses, tables and figure datasets
  collected.mat               Normalised DATA structure
  analysis.mat                Derived numerical diagnostics
  table_data.mat              Returned table data
  figure_data.mat             Figure manifest and numeric payloads
  tables/                     Publication tables and CSV outputs
  figures/                    Main Figure2–6 and FigureS1–S13
    Figure2.png / .pdf / .fig
    Figure2_data.mat          Numeric data, graphics source arrays and caption
    figure_manifest.json
    captions.txt
  raw/
    base/output.mat           Original observations, fits, covariance and diagnostics archive
    postprocess/output.mat    Extended targets and diagnostic payloads
    rotation/output.mat       Stronger-rotation fits and summaries
    bias/output.mat           Directional evaluations and bias summaries
    reparameterization/output.mat
    native/output.mat         Full native chart trial results and population summaries
```

`output.mat` is the convenient publication analysis product. Its `data`, `analysis`, `tables`, `figure_data`, `figures`, and `raw_stage_paths` fields identify all saved products. **The full raw observations and optimiser records are preserved in the stage archives, not duplicated inside the compact unified file.** Keep the raw archives alongside the unified output when archiving a full fresh experiment. Paths to them are relative to the unified output directory; external-input runs may contain `..` components referring to the explicitly supplied source folders.

The original and revision `output.mat` archives embed their per-batch payloads and can be read without depending on checkpoint shards once complete. Use the bundled `jog2.Store` and `pr_read_payload` readers, which verify embedded payload integrity. Do not call unqualified `load` on a large raw archive: load only its `output` metadata variable or use the payload readers. It is safe to `load` the compact unified output normally if sufficient memory is available.

A MAT file ending in `checkpoint.mat` is not a completed output. `state.stages.<stage>.status` is one of `running`, `partial`, `failed`, or `complete`. Absent stages have not been run. `state.complete` means all requested publication products were saved. `output.paper_ready` additionally requires the full paper-profile sample sizes, completed bias traces, full native population coverage, 2,000 valid paired focal fits, all selected target data and the figure-export stage. This flag describes completeness of the prescribed evidence; it is not a claim that every scientific hypothesis passed.

## 6. Interruptions and input integrity

* Resume the same destination with the same numerical configuration and unchanged code. Changes to inputs, computation settings or package MATLAB source produce an identity mismatch rather than mixing results.
* Each completed batch/task is retained. Resume does not refit completed camera batches.
* Do not run two MATLAB processes against the same destination. `RUNNING.lock` prevents concurrent writes.
* A normal error or interruption releases the unified lock through cleanup. After an operating-system crash, a stale lock may remain. First confirm no MATLAB process is writing that run, then remove that particular stale lock and resume. Native-stage locks obey the same rule.
* Keep enough local disk space for raw archives, checkpoint shards, temporary packing files and final exports. A cloud placeholder is not a readable archived payload; use fully downloaded local files.
* No missing stage is filled from the compact reference snapshot. `paper`/`existing` collection stops on missing/incomplete inputs. Reference mode is explicitly labelled in its output.

The reference dataset, MATLAB source and documentation are suitable for a code repository. Large fresh-run raw archives belong in a separately versioned research-data archive. Record the release tag, source manifest and persistent archive DOI together; uploading/publishing is a separate user action.
