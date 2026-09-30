# Reduced-model bootstrap plan

`reduced_bootstrap_counts.mat` contains `counts.J07` and `counts.J08` (uint8, 3000×10000) and `metadata`. Each column gives row multiplicities for one paired bootstrap resample, summing to 3000. The sequence is NumPy PCG64 `default_rng(20260925)`, J07c006 first and J08c005 second. This preserves the original manuscript review's resampling plan without storing 60 million integer indices.

The file contains no measurements, simulated errors or precomputed interval values. `prpaper_reduced` computes the sample-SD statistics and linearly interpolated 2.5/97.5 percentiles from current input errors. Fresh paper-sized runs use the same fixed random plan; smaller profiles use the labelled MATLAB stream. The plan is hashed for resume integrity. See `tools/` for optional reconstruction instructions.
