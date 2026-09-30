"""Create the fixed resampling plan used by the September 25 manuscript check.

NumPy is required only to rebuild this development fixture, not to run MATLAB.
Counts preserve the paired row bootstrap exactly without retaining 60 million
integer row indices. No observed values or computed intervals are embedded.
"""
from pathlib import Path
import argparse
import numpy as np

parser = argparse.ArgumentParser()
parser.add_argument('destination', type=Path)
args = parser.parse_args()
args.destination.mkdir(parents=True, exist_ok=True)
rng = np.random.default_rng(20260925)
for suite in ('J07', 'J08'):
    with (args.destination / f'{suite}_bootstrap_counts.bin').open('wb') as f:
        for start in range(0, 10000, 100):
            indices = rng.integers(0, 3000, size=(100, 3000))
            counts = np.stack([np.bincount(row, minlength=3000) for row in indices])
            assert counts.max() <= 255 and np.all(counts.sum(axis=1) == 3000)
            f.write(counts.astype('uint8').tobytes())
    print(suite, '10000 paired bootstrap count vectors saved')
