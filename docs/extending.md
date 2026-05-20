# Extending to New Years

This guide explains how to add coverage for years beyond 2022 (or adjust the
start year). The process has three parts: update the raw source files, change
two lines in one script, and rebuild.

---

## Step 1 — Update raw source files

Download fresh versions of all three raw files from their original sources
(see `sources/` for URLs and access instructions):

| File | Source | What to get |
|------|--------|-------------|
| `raw/Municipality_historical_directory.xml` | BFS Gemeindeverzeichnis | Re-export the eCH-0071 XML to include mutations up to the new target year |
| `raw/PLZ.csv` | Swiss Post Ortschaftsverzeichnis | Download the snapshot closest to the new target year |
| `raw/medstat.xlsx` | BFS MedStat | Download the correspondence table for the new target year |

Replace the existing files in `raw/` with the new downloads, keeping the
same filenames.

---

## Step 2 — Change two lines in run_all.R

Open `scripts/run_all.R` and update the year range at the top:

```r
YEAR_FROM <- 2012
YEAR_TO   <- 2023   # <-- update this
```

That is the only file you need to edit. All other scripts derive their
year range, file paths, and column names from these two values when run
via `run_all.R`.

---

## Step 3 — Rebuild and validate

```r
Rscript scripts/run_all.R
Rscript validation/validate.R
```

New output files will be created alongside the existing ones:

| New file | Description |
|----------|-------------|
| `lookups/annual/municipality_plz_2023.csv` | PLZ lookup for 2023 |
| `lookups/annual/plz_medstat_2023.csv` | MedStat lookup for 2023 |
| `lookups/annual/municipality_medstat_2023.csv` | Municipality-MedStat for 2023 |
| `lookups/harmonised/municipality_crosswalk_2012_2023.csv` | Crosswalk to 2023 boundaries |
| `lookups/master_lookup_2012_2023.csv` | Full master (historically correct) |
| `lookups/master_lookup_harmonised_2012_2023.csv` | Full master (harmonised to 2023) |

Note: the harmonised files will have `bfs_nr_2023` and `municipality_2023`
columns (instead of `bfs_nr_2022` / `municipality_2022`).

---

## Step 4 — Update documentation

- Add an entry to `CHANGELOG.md` noting the new vintage and data sources used.
- Update the year ranges mentioned in `README.md` if you want to advertise
  the new coverage (search for `2022` in the file).

---

## Running a single script in isolation

Each build script can also be run standalone with its own default year range.
To override, set `YEAR_FROM` and `YEAR_TO` before sourcing, or edit the
defaults at the top of the script:

```r
# At top of any build script (standalone mode)
if (!exists("YEAR_FROM")) YEAR_FROM <- 2012
if (!exists("YEAR_TO"))   YEAR_TO   <- 2022
```

---

## Notes

**XML must cover the new target year.** If your XML export predates the new
`YEAR_TO`, the crosswalk will not include that year's mutations and some
municipalities will be missing. Always re-export the XML when extending.

**Annual scripts are already parameterised.** `build_municipality_plz.R`,
`build_plz_medstat.R`, and `build_municipality_medstat.R` all use a `YEAR`
variable. `run_all.R` loops over the full range automatically.

**Old output files are not deleted.** After rebuilding, both the old
`master_lookup_2012_2022.csv` and the new `master_lookup_2012_2023.csv` will
exist in `lookups/`. Delete the old files if you no longer need them.

**Schlosswil-type splits.** A small number of municipalities that split into
multiple successors cannot be auto-resolved by the crosswalk. These appear as
blank `bfs_nr_{YEAR_TO}` entries. The count is reported when the crosswalk
script runs.
