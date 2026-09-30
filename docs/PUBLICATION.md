# Preparing a research software deposit

This local ZIP has not been uploaded or assigned a new DOI. Version 1.1.0 retains the prior package's MIT license and software creator metadata. `CITATION.cff` and `.zenodo.json` contain no invented repository URL, ORCID or DOI.

Keep the code, compact reference data, resampling plan, source manifest, documentation and validation records together. The `reference_products/` directory provides ready-made results; fresh `runs/`, temporary checkpoints and large raw archives are excluded from the software ZIP.

Before publishing, review the intended software title, creators and license; use the actual persistent identifier assigned by the chosen repository. If depositing full raw runs separately, retain the entire run tree and identify its originating software release. The compact reference dataset is sufficient for the shipped reconstruction, but it is not a deposit of every original image/control observation.

For a versioned release, retain `RELEASE_MANIFEST.json`, `SHA256SUMS` and the actual validation reports. Distinguish the specific software version used by the manuscript from any identifier tracking later versions. Updating source or data requires a new release and new validation evidence.
