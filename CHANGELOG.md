# Changelog

Changes to lookup tables, source updates, and notable Swiss municipality mutations.

## 2026-05 -- Initial release (2012-2022)

- Added master lookup: `lookups/master_lookup_2012_2022.csv` (63,411 rows, one per municipality x PLZ x year; municipality counts correctly decline over time as mergers reduce the total)
- Added harmonised master lookup: `lookups/master_lookup_harmonised_2012_2022.csv` (adds `bfs_nr_2022` / `municipality_2022` columns for consistent cross-year analysis)
- Added municipality crosswalk: `lookups/harmonised/municipality_crosswalk_2012_2022.csv` -- all 2,928 historical BFS numbers mapped to 2022 equivalents via BFS mutation-event chain resolution
- Added annual lookups for 2022: municipality_plz, plz_medstat, municipality_medstat
- Sources: BFS Historisiertes Gemeindeverzeichnis (XML, eCH-0071), Swiss Post Ortschaftsverzeichnis (PLZ), BFS MedStat region table
- MedStat imputed for 5 PLZs absent from the BFS source table (majority-rule from other PLZs in the same municipality)
- Foreign entries (Liechtenstein, Italian enclave, German border) filtered from all Swiss-only lookups

---

## Format

Each entry should note:
- **Date**: when the lookup was updated
- **Vintage year**: reference year of the data
- **Changes**: what changed (new lookup added, municipality merger incorporated, etc.)
- **Source**: link or reference to the official BFS mutation notice if applicable

---

## Municipality mutations

BFS publishes official municipality mutations annually. Key mutation types:
- **Merger (Fusion)**: two or more municipalities merge into one
- **Split (Teilung)**: a municipality splits into two or more
- **Rename**: municipality name changes without boundary change
- **Canton transfer**: municipality moves to a different canton (rare)

Official mutation history: https://www.bfs.admin.ch/bfs/en/home/bases-statistiques/repertoire-officiel-communes-suisse/mutations-communes.html
