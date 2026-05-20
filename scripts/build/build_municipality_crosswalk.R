library(dplyr)
library(readr)
library(xml2)

# Builds a harmonisation crosswalk mapping all municipality BFS numbers
# valid between YEAR_FROM-YEAR_TO to their YEAR_TO equivalents.
#
# Source: BFS historicised municipality register in eCH-0071 XML format
# (raw/Municipality_historical_directory.xml)
#
# Successor resolution: when a municipality was dissolved, its abolition
# mutation number matches the admission mutation number of the successor(s).
# Multi-step chains (A -> B -> C) are resolved iteratively.
#
# When run via run_all.R, YEAR_FROM and YEAR_TO are inherited from there.
# When run standalone, the defaults below are used.
#
# Usage: Rscript scripts/build/build_municipality_crosswalk.R

if (!exists("YEAR_FROM")) YEAR_FROM <- 2012
if (!exists("YEAR_TO"))   YEAR_TO   <- 2022

bfs_target_col  <- paste0("bfs_nr_",       YEAR_TO)
muni_target_col <- paste0("municipality_", YEAR_TO)

raw_file <- "raw/Municipality_historical_directory.xml"

if (!file.exists(raw_file)) {
  stop("Raw file not found: ", raw_file)
}

doc   <- read_xml(raw_file)
nodes <- xml_find_all(doc, ".//municipality")

get_field <- function(node, field) {
  val <- xml_text(xml_find_first(node, field))
  if (is.na(val) || val == "") NA_character_ else val
}

history <- bind_rows(lapply(nodes, function(n) {
  tibble(
    bfs_nr            = as.integer(get_field(n, "municipalityId")),
    municipality      = get_field(n, "municipalityLongName"),
    canton            = get_field(n, "cantonAbbreviation"),
    admission_date    = as.Date(get_field(n, "municipalityAdmissionDate")),
    admission_number  = get_field(n, "municipalityAdmissionNumber"),
    abolition_date    = as.Date(get_field(n, "municipalityAbolitionDate")),
    abolition_number  = get_field(n, "municipalityAbolitionNumber")
  )
}))

window_start <- as.Date(paste0(YEAR_FROM, "-01-01"))
window_end   <- as.Date(paste0(YEAR_TO,   "-12-31"))
target_date  <- as.Date(paste0(YEAR_TO,   "-01-01"))

# Municipalities active at any point during the target year (YEAR_TO).
# Using full year (not just Jan 1) to capture municipalities admitted mid-year.
active_target <- history |>
  filter(
    admission_date <= window_end,
    is.na(abolition_date) | abolition_date >= target_date
  ) |>
  select(bfs_nr, municipality)

# Build a mutation lookup: abolition_number -> successor bfs_nr(s) active in target year.
# Key insight: trace via mutation numbers, not BFS numbers, to avoid
# issues with BFS numbers being reused across validity periods.
mutation_to_successor <- history |>
  filter(!is.na(admission_number)) |>
  select(mutation_number = admission_number, successor_bfs_nr = bfs_nr)

# Resolve chains by following mutation numbers iteratively.
resolve_from_mutation <- function(abolition_mut, mut_map, active, seen_muts = c()) {
  if (is.na(abolition_mut)) return(NA_integer_)
  if (abolition_mut %in% seen_muts) return(NA_integer_)
  seen_muts <- c(seen_muts, abolition_mut)

  successors <- unique(mut_map$successor_bfs_nr[mut_map$mutation_number == abolition_mut])
  if (length(successors) == 0) return(NA_integer_)

  active_s <- successors[successors %in% active]
  if (length(active_s) == 1) return(active_s)
  if (length(active_s) > 1) return(NA_integer_)  # genuine split

  # No direct active successor -- follow each through their own abolition
  next_abolitions <- history$abolition_number[history$bfs_nr %in% successors &
                                               !is.na(history$abolition_number)]
  resolved <- unique(Filter(Negate(is.na), sapply(next_abolitions, function(m) {
    resolve_from_mutation(m, mut_map, active, seen_muts)
  })))
  if (length(resolved) == 1) return(resolved)
  return(NA_integer_)
}

# Municipalities active at any point during YEAR_FROM-YEAR_TO
in_window <- history |>
  filter(
    admission_date <= window_end,
    is.na(abolition_date) | abolition_date >= window_start
  )

active_target_bfs <- active_target$bfs_nr

crosswalk <- in_window |>
  mutate(
    bfs_nr_target = mapply(function(bfs, abol_mut) {
      if (bfs %in% active_target_bfs) return(bfs)
      resolve_from_mutation(abol_mut, mutation_to_successor, active_target_bfs)
    }, bfs_nr, abolition_number)
  ) |>
  left_join(
    active_target |> select(bfs_nr_target = bfs_nr, municipality_target = municipality),
    by = "bfs_nr_target"
  ) |>
  transmute(
    bfs_nr,
    municipality,
    canton,
    valid_from        = format(admission_date, "%Y-%m-%d"),
    valid_to          = format(abolition_date, "%Y-%m-%d"),
    bfs_nr_target,
    municipality_target
  ) |>
  rename(!!bfs_target_col := bfs_nr_target, !!muni_target_col := municipality_target) |>
  arrange(bfs_nr, valid_from)

n_resolved   <- sum(!is.na(crosswalk[[bfs_target_col]]))
n_unresolved <- sum(is.na(crosswalk[[bfs_target_col]]))

if (n_unresolved > 0) {
  message("NOTE: ", n_unresolved, " municipalities could not be automatically resolved.")
  message("These likely involve splits (one municipality -> multiple successors).")
  unresolved <- crosswalk |> filter(is.na(.data[[bfs_target_col]])) |>
    select(bfs_nr, municipality, canton, valid_from, valid_to)
  message("Unresolved:")
  print(unresolved, n = Inf)
}

dir.create("lookups/harmonised", showWarnings = FALSE, recursive = TRUE)
out_file <- paste0("lookups/harmonised/municipality_crosswalk_",
                   YEAR_FROM, "_", YEAR_TO, ".csv")
write_csv(crosswalk, out_file)

message("Written: ", out_file)
message("  Total rows:  ", nrow(crosswalk))
message("  Resolved:    ", n_resolved)
message("  Unresolved:  ", n_unresolved)
