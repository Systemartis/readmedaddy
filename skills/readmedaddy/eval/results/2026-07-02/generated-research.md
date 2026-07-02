# Tidal modulation of microplastic flux in a temperate estuary

![License: CC BY 4.0](https://img.shields.io/badge/license-CC--BY--4.0-lightgrey)

**Finding: ebb-tide microplastic flux is ~2.3x slack-water flux** in a temperate tidal estuary, sampled every 2 hours across one lunar cycle. This repository releases the sampling dataset and the notebook that reproduces the headline figure.

> We quantify microplastic particle flux across a temperate tidal estuary over one lunar cycle and show a 2.3x enrichment on the ebb tide relative to slack water. Code and the sampling dataset are released for reproduction.
>
> — abstract, [`CITATION.cff`](CITATION.cff)

## Results

Figure 2 — mean microplastic particle count per litre by tide phase over the 28-day sampling window ([`results/figure-2-note.md`](results/figure-2-note.md)):

| Tide phase | Mean particles/L |
|---|---|
| flood | 4.25 |
| slack-high | 3.55 |
| ebb | **8.50** |
| slack-low | 3.85 |

Ebb-tide flux is ~2.3x the slack-water mean. The figure is regenerated from `data/samples.csv` on every run, so the number in the abstract and the number in the notebook cannot drift apart.

## Reproduce

The analysis uses only the Python standard library (`csv`, `statistics`); the only tool you need is a Jupyter runner.

```bash
pip install jupyter
jupyter nbconvert --to notebook --execute analysis.ipynb
```

Or open [`analysis.ipynb`](analysis.ipynb) and run it top-to-bottom. Expected output:

```
8 samples loaded
ebb 8.5
flood 4.25
slack-high 3.55
slack-low 3.85
```

## Data

[`data/samples.csv`](data/samples.csv) holds the raw field measurements; full provenance is in [`data/DATASET.md`](data/DATASET.md).

| Column | Type | Description |
|---|---|---|
| `sample_id` | string | unique id per grab sample |
| `tide_phase` | enum | one of `flood`, `slack-high`, `ebb`, `slack-low` |
| `particles_per_l` | float | microplastic particles per litre |
| `temp_c` | float | water temperature, Celsius |

Coordinates and exact dates are withheld to protect the site; tide phase is released instead of absolute timestamps.

## Method

- Grab samples at a single estuary cross-section, every 2 hours over one lunar cycle (28 days), filtered at 0.3 mm.
- Counts are manual under stereo microscope; two counters, blind-cross-checked on 10% of samples.

## Scope and limitations

- One estuary, one cross-section, one lunar cycle. The 2.3x enrichment is a result for this site and window, not a general claim about estuaries.
- Dataset v1.0.0, released 2026-03-18. This repo exists to reproduce one result; it is not a model, a library, or a monitoring tool.
- The DOI in `CITATION.cff` is a placeholder pending archival.

## Citation

If you use this dataset or code, please cite it via [`CITATION.cff`](CITATION.cff):

```bibtex
@dataset{rivera_okafor_2026_tidal,
  author  = {Rivera, A. and Okafor, J.},
  title   = {Tidal modulation of microplastic flux in a temperate estuary},
  version = {1.0.0},
  year    = {2026},
  doi     = {10.0000/zenodo.0000000},
  note    = {Placeholder DOI pending archival}
}
```

## License

Data and code are released under [CC-BY-4.0](CITATION.cff).