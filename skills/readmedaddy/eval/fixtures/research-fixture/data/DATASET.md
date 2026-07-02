# Dataset: estuary microplastic samples

`samples.csv` holds the raw field measurements used by `analysis.ipynb`.

## Provenance

- **Collection:** grab samples at a single estuary cross-section, every 2 hours
  over one lunar cycle (28 days), filtered at 0.3 mm.
- **Instrument:** counts are manual under stereo microscope; two counters,
  blind-cross-checked on 10% of samples.
- **Coordinates and exact dates** are withheld to protect the site; tide phase is
  released instead of absolute timestamps.

## Schema (`samples.csv`)

| Column | Type | Description |
|---|---|---|
| `sample_id` | string | unique id per grab sample |
| `tide_phase` | enum | one of `flood`, `slack-high`, `ebb`, `slack-low` |
| `particles_per_l` | float | microplastic particles per litre |
| `temp_c` | float | water temperature, Celsius |

## License

Data released under CC-BY-4.0. Cite via `CITATION.cff`.
