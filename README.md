# Swiss Geography Look-Ups

Lookup tables mapping between Swiss geographic classification systems used in
administrative and health statistics. Covers 2012-2022.

Built for researchers working with Swiss administrative data who need to link
datasets coded with different geographic identifiers (BFS municipality numbers,
postal codes, MedStat regions, districts, cantons).

## What's included

| Folder | Contents |
|--------|----------|
| `lookups/` | Ready-to-use lookup CSVs — the main output |
| `raw/` | Source files from BFS and Swiss Post (committed for reproducibility) |
| `scripts/build/` | R scripts that produce the lookups from raw data |
| `scripts/fetch/` | R scripts to re-download source files from their original URLs |
| `sources/` | Provenance metadata for each data source (URL, license, vintage) |
| `validation/` | R script that checks lookup integrity |
| `docs/` | Glossary of Swiss geographic classification systems |

## Lookup files

### Master lookups (start here)

One row per municipality × PLZ × year. These are the main deliverable.

| File | Description |
|------|-------------|
| `lookups/master_lookup_2012_2022.csv` | Historically correct boundaries per year |
| `lookups/master_lookup_harmonised_2012_2022.csv` | Same, plus `bfs_nr_2022` / `municipality_2022` for cross-year analysis |

**Which file to use:**
- **Historically correct** (`master_lookup_2012_2022.csv`): use when you want to know what municipality/district/canton a location belonged to *at that time*. If municipality A merged into B in 2016, rows for A appear in 2012-2015 and rows for B appear from 2016 onward.
- **Harmonised** (`master_lookup_harmonised_2012_2022.csv`): use when you want to aggregate or track units consistently over time. The extra `bfs_nr_2022` column maps every row to its 2022 boundary equivalent — grouping by `bfs_nr_2022` means the same geographic unit across all years.

### Columns in the master lookup

| Column | Description |
|--------|-------------|
| `year` | Reference year (2012-2022) |
| `bfs_nr` | BFS municipality number (Gemeindenummer) valid for that year |
| `municipality` | Municipality name valid for that year |
| `bfs_nr_2022` | BFS number of the 2022 successor (harmonised file only) |
| `municipality_2022` | Name of the 2022 successor (harmonised file only) |
| `district_id` | BFS district number |
| `district` | District name |
| `canton_id` | BFS canton number (1-26) |
| `canton_abbr` | Two-letter canton abbreviation (e.g. ZH, BE, GE) |
| `canton` | Full canton name |
| `plz` | 4-digit postal code |
| `medstat_id` | MedStat region code (e.g. ZH01) |
| `medstat_name` | MedStat region name |

### Annual lookups (`lookups/annual/`)

Intermediate tables for a single year. Useful if you only need one step of the chain.

| File | Description |
|------|-------------|
| `municipality_plz_{year}.csv` | All PLZs per municipality (one-to-many) |
| `plz_medstat_{year}.csv` | PLZ to MedStat region |
| `municipality_medstat_{year}.csv` | Municipality to MedStat (majority-rule where boundaries cross) |

### Harmonisation crosswalk (`lookups/harmonised/`)

| File | Description |
|------|-------------|
| `municipality_crosswalk_2012_2022.csv` | All 2012-2022 BFS numbers mapped to their 2022 equivalent |

Use this if you have an external dataset with historical BFS numbers and want to
join it to a 2022-boundary reference, rather than using the full master lookup.

## Quick start (R)

```r
library(readr)

# Load the harmonised master lookup (recommended for most analyses)
master <- read_csv("lookups/master_lookup_harmonised_2012_2022.csv")

# Example: find all PLZs in a canton for a given year
master |>
  dplyr::filter(canton_abbr == "ZH", year == 2018) |>
  dplyr::select(bfs_nr, municipality, plz, medstat_id) |>
  dplyr::distinct()

# Example: map historical BFS numbers in your dataset to 2022 boundaries
your_data |>
  dplyr::left_join(
    dplyr::distinct(master, bfs_nr, year, bfs_nr_2022, municipality_2022),
    by = c("bfs_nr", "year")
  )
```

## Why PLZ is the intermediary for MedStat

MedStat regions are defined at postal code (PLZ) level in the BFS source data,
not at municipality level. The lookup chain is:

```
Municipality (BFS nr) -> PLZ -> MedStat
```

Because PLZ boundaries do not align with municipality boundaries, some
municipalities span multiple MedStat regions. In those cases
(`municipality_medstat_{year}.csv`), the region with the most PLZs is assigned
and the `ambiguous` flag is set to TRUE.

## Extending to new years

To add coverage beyond 2022: update the three raw files with newer vintages,
change `YEAR_TO` in `scripts/run_all.R`, and rebuild. Full instructions in
[`docs/extending.md`](docs/extending.md).

## Reproducing the lookups

The raw source files are committed to this repository, so you can rebuild
everything immediately without downloading anything:

```r
Rscript scripts/run_all.R      # rebuild all lookup files
Rscript validation/validate.R  # check outputs
```

To update to a newer data vintage, download fresh source files using
`scripts/fetch/` (see `sources/` for the URLs) and re-run the above.

## Known limitations

**PLZ assignments approximate for dissolved municipalities.** The Swiss Post
locality register is a single 2022 snapshot. For municipalities that still
existed in 2022, PLZs are exact as of 2022. For municipalities dissolved before
2022 (merged into others), their PLZs are inherited from the 2022 successor —
the best approximation available without historical PLZ archives. PLZ boundary
changes within active municipalities are infrequent in practice.

**MedStat imputed for 5 PLZs.** Five PLZs (3801, 6441, 6549, 6867) are absent
from the BFS MedStat source table. Their MedStat region is imputed using the
most common region among other PLZs in the same municipality.

**One municipality unresolved in the crosswalk.** Schlosswil (BFS 624, BE) split
into multiple successors and cannot be automatically mapped to a single 2022
equivalent. Its `bfs_nr_2022` is blank in the crosswalk and harmonised master.

## Data sources

See [`sources/`](sources/) for provenance, licenses, and access dates for all
source data. See [`docs/glossary.md`](docs/glossary.md) for definitions of each
geographic classification system.

## Geographic systems covered

Municipalities (Gemeinden), districts (Bezirke), cantons, PLZ postal codes,
and MedStat regions. See [`docs/glossary.md`](docs/glossary.md) for details.

## License

Scripts and derived lookup tables are released under the [MIT License](LICENSE).
Source data is subject to the terms of the original providers (see `sources/`).
