# Shared control errors: MATLAB reproducibility package

Version 1.1.0 — companion code for **Shared control errors in single-image self-calibration and space resection: residual observability and confidence-region coverage**

## Quick start

Extract the entire package to a local folder and set that folder as MATLAB's Current Folder. Keep the directory tree intact. Avoid recursively adding all folders to the MATLAB path: legacy convenience scripts share names with the top-level entry points. `prpaper_setup` sets the correct path order.

```matlab
% Reproduce publication figures/tables from included retained numerical data.
file = RUN_REFERENCE;
S = load(file, 'output');
```

This route recomputes the chart statistics, Schur outlines, fixed-metric scatter decomposition, target covariance aggregation and table summaries from saved numerical evidence. It does not generate new observations or refit the original cameras. It is the quickest way to inspect the manuscript results.

```matlab
% Small, separate-seed execution check, followed by the full experiment.
smoke_file = RUN_SMOKE;
paper_file = RUN_PAPER;
```

`RUN_PAPER` performs the complete experiments from generated observations, including the original analytical/reduced-camera suites, E01–E07, the selected stronger-rotation extension, second-order bias diagnostic, direct-focal refits and native-chart postprocessing. It does not substitute bundled paper results for newly computed results. It is a long computation; use a local disk with sufficient free space and preserve the entire run folder.

The completed original base run retained 416,000 camera fits across 123 nonlinear conditions and occupied about 12.2 GB as a final base archive. Checkpoint shards can temporarily require comparable additional space. The rotation extension adds 24,000 fits; the direct-focal diagnostic refits 2,000 retained realisations; the bias stage makes additional deterministic directional fits. A new full run was not repeated merely to package the code. See the shipped validation report for precisely which execution paths were checked.

## Existing completed results

```matlab
opt = prpaper_config('paper');
opt.revision_root = '/path/to/PR_Revision_MATLAB_v1';
opt.native_file = '/path/to/PR_Native_Chart_Postprocess_v1/results/native_chart_paper/output.mat';
file = RUN_EXISTING('/path/to/JoG_MATLAB_v2_1/results/paper_run/output.mat', ...
                    fullfile(pwd,'runs','existing_paper'), opt);
```

The explicit inputs are read-only. Missing revision stages are calculated in the new destination. An existing base archive must contain completed analysis and numerical legacy figure data. The compatible base engine is **JoG v2.1**, embedded under `engines/revision/vendor`, rather than the earlier JoG v2.0 flat-MAT implementation.

## Checkpoint/resume

The wrapper saves `checkpoint.mat` after every stage and the engines save smaller tasks/batches inside `raw/`. Resume with the same package and run folder:

```matlab
file = RUN_RESUME('/path/to/the/run/folder');
```

For a deliberate bounded start, use an explicit configuration:

```matlab
opt = prpaper_config('paper');
opt.destination = fullfile(pwd,'runs','paper_main');
opt.max_batches = 1;
file = prpaper_run('paper',opt);
% Later, complete the same run:
file = RUN_RESUME(opt.destination);
```

A budget pauses the current stage after new tasks have been saved. Completed tasks are reused. Changing numerical settings or source code requires a new destination. Preserve checkpoint files and their `checkpoints/` folders together. After forcibly terminating MATLAB, a stale `RUNNING.lock` may need removal; only remove it after confirming no process is using that run.

## Products

Each completed run contains `output.mat`, `analysis.mat`, `table_data.mat`, `figure_data.mat`, `tables/`, `figures/` and stage checkpoints. Each figure is regenerated as PNG (600 dpi), vector PDF and editable MATLAB FIG, with its own numerical MAT payload. To avoid a verified R2026a large-raster glyph bug, PNG export caps the temporary canvas at 3,900 pixels per side (at most 165.1 mm at 600 dpi), without resampling or reducing font sizes. Vector PDF and FIG retain the intended paper dimensions. Tables are saved as CSV and MATLAB data. Main captions match manuscript v0.19; all captions and source mappings are available in the figure manifest.

For a full experiment, all raw observations, camera fits, fitted covariances, trial identifiers, source settings and intermediate evidence remain in the stage `output.mat` archives under `raw/`. The consolidated `output.mat` embeds the numerical inputs needed for figures/tables and points to these full archives. Archive the **entire run folder** to retain all data, rather than only the top-level MAT file. The bundled reference dataset is deliberately a compact result archive, not a replacement for those complete raw records.

## Requirements and verification

MATLAB with its JVM enabled is required; no Python, Statistics and Machine Learning Toolbox, Optimization Toolbox or Parallel Computing Toolbox is needed by this implementation. R2026a on Apple silicon is the locally exercised environment. Earlier recent MATLAB releases may work but are not claimed as tested. There is no GNU Octave compatibility claim.

```matlab
report = RUN_VALIDATE;
```

This runs analytical identities, archived numerical comparisons and reference-product checks; it does not launch the full paper simulation. `validation/VALIDATION.md` distinguishes runtime checks, archived source evidence and unexecuted long runs.

A fresh run uses the declared random streams/seeds, but cross-release/platform floating-point changes can affect marginal optimiser outcomes. Historical NumPy descriptive curvature-bootstrap intervals are regenerated with an explicitly documented MATLAB stream; they are not claimed to be bitwise identical to NumPy draws. The underlying point estimates and paired inclusion counts are separately verified. The distinct reduced-model sample-SD bootstrap uses the exact retained PCG64 row-resampling plan, so its archived manuscript intervals are reproduced as well. See `docs/MANUSCRIPT_MAP.md` for the distinction.

## Navigation

- [Korean quick start](README_KO.md)
- [Experiments, parameters and seeds](docs/EXPERIMENTS.md)
- [Data formats and resume](docs/DATA_AND_RESUME.md)
- [Figure/table mapping](docs/MANUSCRIPT_MAP.md)
- [Provenance and implementation scope](docs/PROVENANCE.md)
- [GitHub and Zenodo release guide](docs/PUBLICATION.md)

## License and citation

MIT, Copyright (c) 2026 Namhoon Kim. MATLAB is an external tool governed by its own terms and is not redistributed here. See [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md). MATLAB figure styling is regenerated and is not a pixel-identical copy of the original manuscript artwork. Citation metadata are supplied in `CITATION.cff` and `.zenodo.json`. No repository URL, software DOI or journal DOI has been invented. Add real identifiers after publication.
