# Optional development fixture reconstruction

Normal MATLAB execution does not need Python. `rebuild_bootstrap_counts.py` documents/rebuilds the historical NumPy PCG64 paired-row bootstrap plan (seed 20260925, J07 then J08, N=3000, B=10000). It writes two raw uint8 files; each bootstrap replicate is 3000 row multiplicities. These are random indices only, with no observed data or output statistics.

```sh
python rebuild_bootstrap_counts.py /path/to/temporary_counts
```

Import in MATLAB using `fread(fid,[3000 10000],'*uint8')`; column sums must all equal 3000. Save fields `counts.J07`, `counts.J08` and a descriptive `metadata` struct as `data/resampling/reduced_bootstrap_counts.mat` with `-v7`. Rebuilding the fixture is a development operation that changes input hashes and requires a new run directory. The provided binary MAT plan is ready to use.
