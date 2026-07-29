# ============================================================================
# make-synthetic-lab-results.R
#
# ***  SYNTHETIC DATA — NOT REAL.  DO NOT TREAT AS ACTUAL DPH RECORDS.  ***
#
# Builds a FAKE electronic laboratory reporting (ELR) extract for COVID-19
# testing: one row per test result, shaped the way a flattened HL7 v2 ORU^R01
# feed lands in a surveillance system. Every patient, provider, laboratory,
# CLIA number, specimen ID and accession number below is invented. The only
# things that are real are the *vocabularies* — LOINC, SNOMED CT and ICD-10-CM
# codes are the genuine published codes, because the point of this dataset is
# to practice on data that looks like the real feed.
#
# Two things make this dataset worth teaching with:
#
#   1. THE ICD-10 ERA SWITCH. There was no COVID-19 diagnosis code at the start
#      of the pandemic. Diagnoses arrived as B34.2 (coronavirus infection,
#      unspecified) and B97.29 (other coronavirus as the cause of diseases
#      classified elsewhere) — the pre-existing coronavirus codes. U07.1
#      (COVID-19) only became effective 2020-04-01 in the US, and the
#      Z20.822 / Z11.52 / J12.82 codes only on 2021-01-01. Real feeds did not
#      switch cleanly: some senders kept emitting B97.29 for months. So a naive
#      `filter(dx_code == "U07.1")` silently drops the whole first wave. The
#      generator reproduces that lag on purpose.
#
#   2. SCALE. `--rows` goes as high as you have patience for. A few hundred
#      thousand rows is a comfortable CSV. Ten million is not — that is the
#      wall readers should hit with `read_csv()` before arrow/duckdb/parquet
#      is introduced as the answer. Rows are generated and appended in chunks,
#      so the generator itself never holds the whole table in memory.
#
# Usage:
#   Rscript data-raw/make-synthetic-lab-results.R
#   Rscript data-raw/make-synthetic-lab-results.R --rows 5000000
#   Rscript data-raw/make-synthetic-lab-results.R --rows 2e7 --out /tmp/big.csv
#   Rscript data-raw/make-synthetic-lab-results.R --rows 1e6 --format parquet
#   Rscript data-raw/make-synthetic-lab-results.R --messy
#   Rscript data-raw/make-synthetic-lab-results.R --messy-parts dates,towns
#
# --messy adds a third teaching layer on top of the two above: SENDER QUIRKS.
# Each laboratory gets its own datetime format, its own result wording, and
# possibly its own non-LOINC test codes, held consistent across all of that
# lab's rows — because a sending system is not randomly messy, it is
# reliably messy in one particular way. Town spellings wobble per row, since
# those come from a person at a keyboard rather than from an interface engine.
# Layers can be selected individually: dates, towns, codes, text.
#
# Deterministic: a fixed seed plus id-derived patient attributes mean the same
# --rows always produces the same file, and the first 25,000 rows of a
# ten-million-row run are the same 25,000 rows as a small run.
#
# Produces (by default): data/synthetic-covid-lab-results.csv
# ============================================================================

suppressPackageStartupMessages({
  library(dplyr)
  library(readr)
  library(stringr)
})

# --- 0. Arguments ------------------------------------------------------------

args <- commandArgs(trailingOnly = TRUE)

arg_value <- function(flag, default) {
  hit <- which(args == flag)
  if (length(hit) == 0) {
    return(default)
  }
  args[hit[1] + 1]
}

n_rows <- as.numeric(arg_value("--rows", "25000"))
out_path <- arg_value(
  "--out",
  here::here("data", "synthetic-covid-lab-results.csv")
)
out_format <- arg_value("--format", "csv")
seed <- as.integer(arg_value("--seed", "20200401")) # the day U07.1 went live
chunk_size <- as.numeric(arg_value("--chunk", "250000"))

# --messy layers on the sender-specific corruptions described in section 8.
# Off by default, so the baseline file stays the tidy-ish one. Individual
# layers can be selected with --messy-parts dates,towns,codes,text.
all_messy_parts <- c("dates", "towns", "codes", "text")
messy <- "--messy" %in% args || "--messy-parts" %in% args
messy_parts <- if (messy) {
  requested <- arg_value(
    "--messy-parts",
    paste(all_messy_parts, collapse = ",")
  )
  trimws(strsplit(requested, ",")[[1]])
} else {
  character(0)
}
unknown <- setdiff(messy_parts, all_messy_parts)
if (length(unknown) > 0) {
  stop(
    "--messy-parts must be from: ",
    paste(all_messy_parts, collapse = ", "),
    ". Got: ",
    paste(unknown, collapse = ", ")
  )
}

stopifnot(n_rows >= 1, chunk_size >= 1)
set.seed(seed)

# --- 1. Reference vocabularies -----------------------------------------------
# Real codes. These are what a surveillance analyst actually sees in the feed,
# and the reason a lookup table is unavoidable: `94500-6` means nothing on its
# own.

# LOINC — what was ordered and what was performed. Ordered and performed are
# different fields in HL7 (OBR-4 vs OBX-3) and really do differ: you order a
# panel and the lab reports the individual analyte.
loinc_pcr <- tibble::tibble(
  test_performed_loinc = c("94500-6", "94309-2", "94759-8", "94534-5"),
  test_performed_name = c(
    "SARS-CoV-2 (COVID-19) RNA [Presence] in Respiratory specimen by NAA with probe detection",
    "SARS-CoV-2 (COVID-19) RNA [Presence] in Specimen by NAA with probe detection",
    "SARS-CoV-2 (COVID-19) RNA [Presence] in Nasopharynx by NAA with probe detection",
    "SARS-CoV-2 (COVID-19) RdRp gene [Presence] in Respiratory specimen by NAA with probe detection"
  )
)

loinc_antigen <- tibble::tibble(
  test_performed_loinc = c("94558-4", "97097-0"),
  test_performed_name = c(
    "SARS-CoV-2 (COVID-19) Ag [Presence] in Respiratory specimen by Rapid immunoassay",
    "SARS-CoV-2 (COVID-19) Ag [Presence] in Upper respiratory specimen by Rapid immunoassay"
  )
)

loinc_serology <- tibble::tibble(
  test_performed_loinc = c("94563-4", "94562-6", "94769-7"),
  test_performed_name = c(
    "SARS-CoV-2 (COVID-19) IgG Ab [Presence] in Serum or Plasma by Immunoassay",
    "SARS-CoV-2 (COVID-19) IgM Ab [Presence] in Serum or Plasma by Immunoassay",
    "SARS-CoV-2 (COVID-19) IgG and IgM panel - Serum or Plasma by Immunoassay"
  )
)

# SNOMED CT — the coded result (OBX-5 when the value type is CE/CWE).
snomed_result <- c(
  detected = "260373001", # Detected
  not_detected = "260415000", # Not detected
  inconclusive = "419984006", # Inconclusive
  invalid = "455371000124106", # Invalid result
  unsatisfactory = "125154007", # Specimen unsatisfactory for evaluation
  positive = "10828004", # Positive
  negative = "260385009", # Negative
  indeterminate = "82334004" # Indeterminate
)

# SNOMED CT — specimen source (SPM-4). Which sources are plausible depends on
# the assay, so these are grouped rather than pooled: a rapid antigen test is
# never run on bronchoalveolar lavage fluid, and serology needs blood.
# `upper` marks the sources an antigen test can legitimately come from.
spec_respiratory <- tibble::tibble(
  specimen_source_snomed = c(
    "258500001",
    "697989009",
    "871810001",
    "461911000124106",
    "258529004",
    "119342007",
    "119334006",
    "258607008"
  ),
  specimen_source = c(
    "Nasopharyngeal swab",
    "Anterior nares swab",
    "Mid-turbinate nasal swab",
    "Oropharyngeal swab",
    "Throat swab",
    "Saliva specimen",
    "Sputum specimen",
    "Bronchoalveolar lavage fluid sample"
  ),
  upper = c(TRUE, TRUE, TRUE, TRUE, TRUE, TRUE, FALSE, FALSE),
  weight = c(0.46, 0.24, 0.12, 0.07, 0.04, 0.04, 0.02, 0.01)
)

spec_blood <- tibble::tibble(
  specimen_source_snomed = c("119364003", "119361006"),
  specimen_source = c("Serum specimen", "Plasma specimen")
)

# ICD-10-CM diagnosis codes, by the era in which a sender could legitimately
# use them. Dates are the US effective dates, not guesses.
#
#   era 1  (through 2020-03-31) no COVID code exists
#   era 2  (2020-04-01 onward)  U07.1 exists
#   era 3  (2021-01-01 onward)  the Z20.822 / Z11.52 / J12.82 batch exists
icd_era1 <- c(
  "B34.2", # Coronavirus infection, unspecified
  "B97.29", # Other coronavirus as the cause of diseases classified elsewhere
  "J12.89", # Other viral pneumonia
  "J20.8", # Acute bronchitis due to other specified organisms
  "J22", # Unspecified acute lower respiratory infection
  "J80", # Acute respiratory distress syndrome
  "R05", # Cough
  "R06.02", # Shortness of breath
  "R50.9", # Fever, unspecified
  "Z20.828", # Contact with/exposure to other viral communicable diseases
  "Z03.818" # Observation for suspected exposure, ruled out
)
icd_era1_prob <- c(
  0.20,
  0.22,
  0.06,
  0.04,
  0.03,
  0.02,
  0.10,
  0.07,
  0.12,
  0.10,
  0.04
)

icd_era2 <- c(
  "U07.1", # COVID-19
  "B97.29", # senders who had not switched yet
  "B34.2",
  "J12.89",
  "J80",
  "R05",
  "R06.02",
  "R50.9",
  "Z20.828",
  "Z03.818"
)
icd_era2_prob <- c(0.44, 0.14, 0.04, 0.05, 0.02, 0.08, 0.05, 0.08, 0.07, 0.03)

icd_era3 <- c(
  "U07.1",
  "Z20.822", # Contact with and (suspected) exposure to COVID-19
  "Z11.52", # Encounter for screening for COVID-19
  "J12.82", # Pneumonia due to coronavirus disease 2019
  "Z86.16", # Personal history of COVID-19
  "M35.81", # Multisystem inflammatory syndrome
  "B97.29", # a stubborn tail of senders, still
  "R05.1",
  "R50.9",
  "Z03.818"
)
icd_era3_prob <- c(0.34, 0.22, 0.18, 0.04, 0.05, 0.01, 0.03, 0.05, 0.05, 0.03)

# --- 2. Fictional laboratories -----------------------------------------------
# Names, CLIA numbers and ID formats are all invented. The ID formats differ
# deliberately: every lab in a real feed numbers its specimens its own way, and
# that is exactly why specimen_id cannot be parsed with one regex.
labs <- tibble::tibble(
  performing_lab = c(
    "Nutmeg Regional Reference Laboratory",
    "Charter Oak Molecular Pathology",
    "Housatonic Valley Hospital Clinical Lab",
    "Quinnipiac Diagnostics of New England",
    "Farmington River Medical Center Laboratory",
    "State Public Health Reference Laboratory (SIMULATED)",
    "Bramblebush Urgent Care Testing Network",
    "Sound Shore Mobile Collection Services"
  ),
  performing_lab_clia = c(
    "07D2148765",
    "07D1093322",
    "07D0774519",
    "07D2560184",
    "07D0338907",
    "07D0000001",
    "07D1877402",
    "07D2901556"
  ),
  lab_kind = c(
    "commercial",
    "commercial",
    "hospital",
    "commercial",
    "hospital",
    "public_health",
    "urgent_care",
    "collection_site"
  ),
  id_prefix = c("NRL", "COMP", "HVH", "QDNE", "FRMC", "PHL", "BUC", "SSM"),
  id_style = c(
    "prefix_date_seq",
    "numeric",
    "alpha_year",
    "numeric",
    "alpha_year",
    "prefix_date_seq",
    "numeric",
    "prefix_date_seq"
  ),
  weight = c(0.30, 0.18, 0.14, 0.12, 0.09, 0.06, 0.06, 0.05),

  # --- sender quirks, used only when --messy is on -------------------------
  # A sending system is not randomly messy. It is *consistently* messy in its
  # own particular way, because somebody configured an interface engine once
  # in 2020 and nobody has touched it since. So these are lab attributes, not
  # per-row coin flips: once you work out how Quinnipiac writes a timestamp,
  # every Quinnipiac row follows the same rule.
  dt_style = c(
    "iso", # 2021-02-06T13:28:51Z
    "hl7", # 20210206132851-0500
    "excel", # 2021-02-06 13:28:51
    "us_slash", # 2/6/2021 1:28 PM
    "excel",
    "iso",
    "us_slash",
    "date_only" # 02/06/2021 — the time is simply gone
  ),
  code_style = c(
    "loinc",
    "local", # sends its own compendium codes until it gets onboarded
    "loinc",
    "local",
    "loinc",
    "loinc",
    "local",
    "loinc"
  ),
  text_style = c(
    "standard", # Detected / Not detected
    "shout", # DETECTED / NOT DETECTED
    "standard",
    "abbrev", # POS / NEG / IND
    "verbose", # Positive for SARS-CoV-2 (COVID-19) by RT-PCR
    "standard",
    "abbrev",
    "shout"
  )
)

ordering_facilities <- c(
  "Housatonic Valley Hospital Emergency Department",
  "Farmington River Medical Center - Internal Medicine",
  "Bramblebush Urgent Care - Newington",
  "Bramblebush Urgent Care - Enfield",
  "Tunxis Family Health Associates",
  "Talcott Mountain Pediatrics",
  "Elm Ridge Skilled Nursing Facility",
  "Riverbend Community Health Center",
  "Town of Manchester Health Department",
  "Sound Shore Mobile Collection Services - Drive Thru",
  "Copper Beech Correctional Infirmary",
  "Nutmeg University Student Health Services"
)

instruments <- c(
  "PathSeeker RT-PCR 2000",
  "OpenPlex 96 Thermocycler",
  "Nutmeg NAAT Cartridge System",
  "RapidSense Ag Reader",
  "SeroLume 400 Immunoanalyzer"
)

# The 29 towns of Hartford County — the same geography as the synthetic
# line-list, so the two datasets can be joined in a later chapter.
hartford_county <- c(
  "Avon",
  "Berlin",
  "Bloomfield",
  "Bristol",
  "Burlington",
  "Canton",
  "East Granby",
  "East Hartford",
  "East Windsor",
  "Enfield",
  "Farmington",
  "Glastonbury",
  "Granby",
  "Hartford",
  "Hartland",
  "Manchester",
  "Marlborough",
  "New Britain",
  "Newington",
  "Plainville",
  "Rocky Hill",
  "Simsbury",
  "Southington",
  "South Windsor",
  "Suffield",
  "West Hartford",
  "Wethersfield",
  "Windsor",
  "Windsor Locks"
)
# Population weights, roughly: the cities test more than Hartland does.
town_weight <- c(
  2,
  2,
  2,
  6,
  1,
  1,
  1,
  8,
  1,
  5,
  3,
  3,
  1,
  16,
  1,
  8,
  1,
  9,
  3,
  2,
  2,
  2,
  4,
  3,
  2,
  8,
  3,
  3,
  1
)

surnames <- c(
  "Alvarez",
  "Bailey",
  "Baptiste",
  "Bernard",
  "Brennan",
  "Cabrera",
  "Calderon",
  "Carr",
  "Chen",
  "Colon",
  "Conley",
  "Cruz",
  "Delgado",
  "Desrosiers",
  "Doyle",
  "Duffy",
  "Escobar",
  "Fitzgerald",
  "Fontaine",
  "Gagnon",
  "Garcia",
  "Gilbert",
  "Grant",
  "Gutierrez",
  "Hall",
  "Hernandez",
  "Holloway",
  "Ivanov",
  "Jackson",
  "Jean-Baptiste",
  "Kowalski",
  "Lachance",
  "Laurent",
  "Leblanc",
  "Lopez",
  "Mancini",
  "Marchetti",
  "Mbeki",
  "McCarthy",
  "Medina",
  "Mercado",
  "Moreau",
  "Nguyen",
  "Nowak",
  "Obrien",
  "Okafor",
  "Ortiz",
  "Pappas",
  "Patel",
  "Pereira",
  "Petrov",
  "Phan",
  "Quintana",
  "Ramirez",
  "Reyes",
  "Rivera",
  "Rodriguez",
  "Rosario",
  "Russo",
  "Santiago",
  "Santos",
  "Silva",
  "Sullivan",
  "Sylvain",
  "Tavares",
  "Thibodeau",
  "Torres",
  "Tran",
  "Vasquez",
  "Walsh",
  "Whitaker",
  "Wong",
  "Yang",
  "Zielinski"
)

first_names <- c(
  "Aaliyah",
  "Abel",
  "Adrian",
  "Alice",
  "Amara",
  "Andre",
  "Angela",
  "Anthony",
  "Aracely",
  "Bernice",
  "Brian",
  "Camila",
  "Carlos",
  "Catherine",
  "Cedric",
  "Chantal",
  "Damaris",
  "Daniel",
  "Dawn",
  "Denise",
  "Diego",
  "Dmitri",
  "Edward",
  "Elaine",
  "Elena",
  "Emeka",
  "Eugene",
  "Fatima",
  "Felix",
  "Francesca",
  "Gabriel",
  "Gerald",
  "Grace",
  "Hector",
  "Helen",
  "Ibrahim",
  "Irene",
  "Isaac",
  "Jacqueline",
  "Janice",
  "Javier",
  "Jean",
  "Jennifer",
  "Joan",
  "Jorge",
  "Joseph",
  "Karina",
  "Keisha",
  "Kevin",
  "Krystal",
  "Lamar",
  "Leonard",
  "Lucia",
  "Malik",
  "Marguerite",
  "Maria",
  "Marisol",
  "Marta",
  "Michael",
  "Miriam",
  "Nadia",
  "Nathan",
  "Nicole",
  "Olga",
  "Omar",
  "Patricia",
  "Paul",
  "Priya",
  "Rafael",
  "Ramona",
  "Raymond",
  "Rosa",
  "Ruth",
  "Samuel",
  "Sandra",
  "Sergio",
  "Sofia",
  "Stanley",
  "Tamara",
  "Terrence",
  "Thao",
  "Theresa",
  "Tomas",
  "Vanessa",
  "Victor",
  "Wanda",
  "Wei",
  "Yolanda",
  "Yusuf"
)

# --- 3. Deterministic pseudo-random helpers ----------------------------------
# Patient attributes are DERIVED from the patient id rather than stored in a
# lookup table. That keeps memory flat at any --rows, and it means the same
# patient id always yields the same name, DOB and town no matter which chunk
# it turns up in — so a person who gets tested five times looks like one
# person five times.

# Hash an (id, salt) pair to an integer in [0, m).
#
# The obvious version of this — a Lehmer step on `id + salt * k` — is wrong,
# and wrong in a way worth knowing about: multiplication and addition modulo m
# are linear, so every salt produces the SAME sequence, merely shifted. Two
# attributes drawn with two different salts would then be perfectly correlated,
# and every patient in a given town would share a name and a race. The xor and
# shift steps below break that linearity, so the salts really are independent.
# (Note the parentheses around every modulo: in R, `%%` binds TIGHTER than
# `*`, so `x %% m * a %% m` is not the multiply-then-reduce it looks like.)
keyed_hash <- function(id, salt) {
  m <- 2147483647
  h <- ((id %% m) * 48271) %% m
  h <- bitwXor(as.integer(h), as.integer((salt * 374761393) %% m))
  h <- as.integer((as.numeric(h) * 16807) %% m)
  h <- bitwXor(h, bitwShiftR(h, 15))
  # A second multiply-and-xorshift round. One round leaves correlations of
  # ~0.18 between salts; two rounds drop that to ~0.007, which is what you
  # want if "town" and "race" are supposed to be independent draws.
  h <- as.integer((as.numeric(h) * 48271) %% m)
  bitwXor(h, bitwShiftR(h, 13))
}

# A [0, 1) draw keyed on (id, salt) — same inputs, same number, forever.
keyed_unif <- function(id, salt) {
  keyed_hash(id, salt) / 2147483647
}

# Pick from a vector by keyed draw.
keyed_pick <- function(id, salt, choices) {
  choices[floor(keyed_unif(id, salt) * length(choices)) + 1]
}

# Weighted sample helper — `prob` need not sum to 1.
wsample <- function(x, size, prob) {
  sample(x, size, replace = TRUE, prob = prob / sum(prob))
}

# NPI check digit: Luhn over "80840" + the 9-digit base. Fake NPIs that fail a
# Luhn check are the sort of thing a validation script catches, so these pass.
npi_from_base <- function(base9) {
  digits <- as.integer(unlist(strsplit(
    paste0("80840", sprintf("%09.0f", base9)),
    ""
  )))
  digits <- matrix(digits, nrow = length(base9), byrow = TRUE)
  # Double every second digit from the right of the 14-digit prefix.
  pos <- ncol(digits):1
  dbl <- (pos %% 2) == 1
  vals <- digits
  vals[, dbl] <- vals[, dbl] * 2
  vals[vals > 9] <- vals[vals > 9] - 9
  total <- rowSums(vals)
  check <- (10 - (total %% 10)) %% 10
  paste0(sprintf("%09.0f", base9), check)
}

# --- 3b. Sender-quirk helpers (only used when --messy) -----------------------

# US Eastern UTC offset for a date. Hard-coded DST windows for the two years
# this dataset covers, which is cheaper and more legible than a timezone
# lookup per row.
eastern_offset <- function(d) {
  dst <- (d >= as.Date("2020-03-08") & d < as.Date("2020-11-01")) |
    (d >= as.Date("2021-03-14") & d < as.Date("2021-11-07"))
  ifelse(dst, "-0400", "-0500")
}

# Write a timestamp the way one particular sender writes it. Timestamps here
# are naive local time; `hl7` stamps the offset on rather than converting.
# `date_only` is the cruel one — that sender's times are simply gone, and no
# amount of parsing brings them back.
format_dt <- function(dt, style) {
  out <- character(length(dt))
  d <- as.Date(dt)
  for (s in unique(style)) {
    i <- which(style == s)
    out[i] <- switch(
      s,
      hl7 = paste0(
        format(dt[i], "%Y%m%d%H%M%S", tz = "UTC"),
        eastern_offset(d[i])
      ),
      excel = format(dt[i], "%Y-%m-%d %H:%M:%S", tz = "UTC"),
      us_slash = {
        v <- format(dt[i], "%m/%d/%Y %I:%M %p", tz = "UTC")
        # This sender's export drops leading zeros on month, day and hour.
        v <- sub("^0", "", v)
        v <- sub("/0", "/", v)
        sub(" 0", " ", v)
      },
      date_only = format(dt[i], "%m/%d/%Y", tz = "UTC"),
      format(dt[i], "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
    )
  }
  out[is.na(dt)] <- NA_character_
  out
}

# Transpose two adjacent letters — the classic data-entry typo.
swap_letters <- function(x) {
  vapply(
    strsplit(x, ""),
    function(ch) {
      if (length(ch) >= 6) {
        tmp <- ch[4]
        ch[4] <- ch[5]
        ch[5] <- tmp
      }
      paste(ch, collapse = "")
    },
    character(1)
  )
}

# Corrupt a town name the way a registration clerk does. Note this is applied
# PER ROW, while the underlying town is a property of the patient: the same
# person really does turn up as "West Hartford", "W. Hartford" and "WEST
# HARTFORD" across three visits. Standardizing on the raw string fails.
messy_town <- function(town) {
  r <- runif(length(town))
  out <- town
  i <- r < 0.08
  out[i] <- toupper(out[i])
  i <- r >= 0.08 & r < 0.16
  out[i] <- sub("^(N|S|E|W)[a-z]+ ", "\\1. ", out[i])
  i <- r >= 0.16 & r < 0.20
  out[i] <- tolower(out[i])
  i <- r >= 0.20 & r < 0.23
  out[i] <- swap_letters(out[i])
  i <- r >= 0.23 & r < 0.26
  out[i] <- paste0(out[i], "  ")
  out
}

# Patients whose specimen was collected in Hartford County but who live
# somewhere else — including out of state. Keyed on the patient id, because a
# person's home address does not move between visits.
out_of_area <- tibble::tibble(
  town = c(
    "New Haven",
    "Bridgeport",
    "Waterbury",
    "Norwich",
    "Stamford",
    "Springfield",
    "Westerly",
    "Worcester"
  ),
  county = c(
    "New Haven",
    "Fairfield",
    "New Haven",
    "New London",
    "Fairfield",
    "Hampden",
    "Washington",
    "Worcester"
  ),
  state = c("CT", "CT", "CT", "CT", "CT", "MA", "RI", "MA")
)

# Local compendium codes. A lab that has not finished LOINC onboarding sends
# whatever its own LIS calls the test, and every lab calls it something else.
local_test_code <- function(prefix, test_class) {
  dplyr::case_when(
    prefix == "COMP" & test_class == "pcr" ~ "30412",
    prefix == "COMP" & test_class == "antigen" ~ "30455",
    prefix == "COMP" ~ "30987",
    prefix == "QDNE" & test_class == "pcr" ~ "COVIDPCR",
    prefix == "QDNE" & test_class == "antigen" ~ "COVIDAG",
    prefix == "QDNE" ~ "COVIDABPNL",
    prefix == "BUC" & test_class == "pcr" ~ "BUC-COV19-NAA",
    prefix == "BUC" & test_class == "antigen" ~ "BUC-COV19-AG",
    TRUE ~ "BUC-COV19-AB"
  )
}

# The same coded result, written four different ways. `result_snomed` stays
# correct throughout, which is the lesson: trust the code, not the text.
drift_result_text <- function(value, style, test_method) {
  out <- value
  i <- style == "shout"
  out[i] <- toupper(out[i])

  i <- style == "abbrev"
  out[i] <- dplyr::recode(
    out[i],
    "Detected" = "POS",
    "Positive" = "POS",
    "Not detected" = "NEG",
    "Negative" = "NEG",
    "Inconclusive" = "IND",
    "Invalid result" = "INV",
    "Specimen unsatisfactory for evaluation" = "QNS",
    .default = out[i]
  )

  i <- style == "verbose"
  out[i] <- dplyr::case_when(
    value[i] == "Detected" ~
      paste0("Positive for SARS-CoV-2 (COVID-19) by ", test_method[i]),
    value[i] == "Not detected" ~ "No SARS-CoV-2 (COVID-19) RNA detected",
    value[i] == "Positive" ~ "Reactive for SARS-CoV-2 (COVID-19) antibody",
    value[i] == "Negative" ~ "Non-reactive for SARS-CoV-2 (COVID-19) antibody",
    value[i] == "Inconclusive" ~ "Equivocal - unable to interpret",
    TRUE ~ value[i]
  )
  out
}

# --- 4. Time shape -----------------------------------------------------------
# Testing volume is not uniform across the pandemic. Two things drive it:
# capacity (there was essentially no community testing before mid-March 2020)
# and waves. This curve is illustrative, not fitted.

date_start <- as.Date("2020-01-15")
date_end <- as.Date("2021-06-30")
all_dates <- seq(date_start, date_end, by = "day")

day_index <- as.numeric(all_dates - as.Date("2020-01-01"))
bump <- function(t, mu, sd, amp) amp * exp(-0.5 * ((t - mu) / sd)^2)

volume_weight <-
  # capacity ramp: nothing much until testing existed
  stats::plogis((day_index - 72) / 10) *
  (0.06 +
    bump(day_index, 105, 32, 0.30) + # spring 2020 wave
    bump(day_index, 250, 45, 0.22) + # late-summer baseline testing
    bump(day_index, 378, 38, 1.00) + # winter 2020-21 surge
    bump(day_index, 435, 30, 0.35)) # spring 2021 tail

# Test-positivity also moves: high and noisy in spring 2020 when only the very
# sick got swabbed, low in the summer, high again in the winter surge.
positivity <- pmin(
  pmax(
    0.02 +
      bump(day_index, 100, 25, 0.24) +
      bump(day_index, 378, 40, 0.13),
    0.01
  ),
  0.35
)
names(positivity) <- as.character(all_dates)

# Assay availability by date. Antigen tests were not authorized until well into
# 2020; serology arrives in the spring.
p_antigen <- 0.45 * stats::plogis((day_index - 240) / 25)
p_serology <- 0.10 * stats::plogis((day_index - 110) / 20)
names(p_antigen) <- as.character(all_dates)
names(p_serology) <- as.character(all_dates)

# --- 5. Chunk generator ------------------------------------------------------
# One call builds `n` rows. `offset` keeps ids unique across chunks.

make_chunk <- function(n, offset) {
  # -- who was tested ---------------------------------------------------------
  # ~62% of results belong to a patient who is tested more than once, which is
  # what makes deduplication a real exercise. Repeat testers are drawn from a
  # smaller pool than the row count.
  pool <- max(1, round(n_rows * 0.62))
  pid <- sample.int(pool, n, replace = TRUE)

  # Attributes derived from the id, so they follow the patient across chunks.
  dob <- as.Date("1930-01-01") +
    floor(keyed_unif(pid, 3) * 32000) # through ~2017
  sex_raw <- keyed_pick(pid, 5, c("F", "M", "M", "F", "U"))
  # Town is a weighted pick, still keyed on the id: Hartford tests far more
  # people than Hartland does, but a given patient always lives in one place.
  town_cum <- cumsum(town_weight) / sum(town_weight)
  town <- hartford_county[
    pmin(
      findInterval(keyed_unif(pid, 7), town_cum) + 1,
      length(hartford_county)
    )
  ]

  # -- when -------------------------------------------------------------------
  collect_date <- wsample(all_dates, n, volume_weight)
  d_chr <- as.character(collect_date)

  # Collections cluster in daytime hours.
  collect_dt <- as.POSIXct(
    as.numeric(as.POSIXct(paste(collect_date, "00:00:00"), tz = "UTC")) +
      pmin(pmax(round(rnorm(n, 11.5, 3.2)), 0), 23) * 3600 +
      sample.int(3600, n, replace = TRUE),
    origin = "1970-01-01",
    tz = "UTC"
  )

  # Turnaround got much worse during the surges. Courier to the lab, then
  # bench time, then the report out to public health.
  surge_drag <- 1 +
    2.2 * bump(as.numeric(collect_date - as.Date("2020-01-01")), 378, 35, 1) +
    1.5 * bump(as.numeric(collect_date - as.Date("2020-01-01")), 105, 30, 1)
  received_dt <- collect_dt + rexp(n, 1 / (10 * 3600)) * surge_drag + 1800
  result_dt <- received_dt + rexp(n, 1 / (14 * 3600)) * surge_drag + 3600
  reported_dt <- result_dt + rexp(n, 1 / (8 * 3600)) + 600

  # -- where it was run -------------------------------------------------------
  lab_i <- wsample(seq_len(nrow(labs)), n, labs$weight)
  lab <- labs[lab_i, ]

  seq_no <- offset + seq_len(n)
  specimen_id <- dplyr::case_when(
    lab$id_style == "prefix_date_seq" ~
      paste0(
        lab$id_prefix,
        "-",
        format(collect_date, "%Y%m%d"),
        "-",
        sprintf("%05d", seq_no %% 100000)
      ),
    lab$id_style == "numeric" ~ sprintf("%010.0f", 4000000000 + seq_no),
    TRUE ~
      paste0(
        lab$id_prefix,
        format(collect_date, "%y"),
        "-",
        sprintf("%06d", seq_no %% 1000000)
      )
  )
  accession_number <- paste0(
    lab$id_prefix,
    "A",
    sprintf("%09.0f", 100000000 + seq_no * 7)
  )

  # -- what was ordered and run -----------------------------------------------
  u <- runif(n)
  pa <- p_antigen[d_chr]
  ps <- p_serology[d_chr]
  test_class <- dplyr::case_when(
    u < ps ~ "serology",
    u < ps + pa ~ "antigen",
    TRUE ~ "pcr"
  )

  pick_row <- function(tbl, k) tbl[sample.int(nrow(tbl), k, replace = TRUE), ]

  performed <- dplyr::bind_rows(
    pick_row(loinc_pcr, n)
  )
  ag <- pick_row(loinc_antigen, n)
  se <- pick_row(loinc_serology, n)
  test_performed_loinc <- dplyr::case_when(
    test_class == "antigen" ~ ag$test_performed_loinc,
    test_class == "serology" ~ se$test_performed_loinc,
    TRUE ~ performed$test_performed_loinc
  )
  test_performed_name <- dplyr::case_when(
    test_class == "antigen" ~ ag$test_performed_name,
    test_class == "serology" ~ se$test_performed_name,
    TRUE ~ performed$test_performed_name
  )
  test_ordered_loinc <- dplyr::case_when(
    test_class == "antigen" ~ "94558-4",
    test_class == "serology" ~ "94769-7",
    TRUE ~ "94531-1"
  )
  test_ordered_name <- dplyr::case_when(
    test_class == "antigen" ~
      "SARS-CoV-2 (COVID-19) Ag [Presence] in Respiratory specimen by Rapid immunoassay",
    test_class == "serology" ~
      "SARS-CoV-2 (COVID-19) IgG and IgM panel - Serum or Plasma by Immunoassay",
    TRUE ~
      "SARS-CoV-2 (COVID-19) RNA panel - Respiratory specimen by NAA with probe detection"
  )
  test_method <- dplyr::case_when(
    test_class == "antigen" ~ "Rapid immunoassay",
    test_class == "serology" ~ "Chemiluminescent immunoassay",
    TRUE ~ sample(
      c("RT-PCR", "Isothermal NAA"),
      n,
      replace = TRUE,
      prob = c(0.88, 0.12)
    )
  )
  instrument_model <- dplyr::case_when(
    test_class == "antigen" ~ "RapidSense Ag Reader",
    test_class == "serology" ~ "SeroLume 400 Immunoanalyzer",
    TRUE ~ sample(instruments[1:3], n, replace = TRUE)
  )

  upper_only <- spec_respiratory[spec_respiratory$upper, ]
  resp <- spec_respiratory[
    wsample(seq_len(nrow(spec_respiratory)), n, spec_respiratory$weight),
  ]
  upper <- upper_only[
    wsample(seq_len(nrow(upper_only)), n, upper_only$weight),
  ]
  bld <- pick_row(spec_blood, n)
  specimen_source_snomed <- dplyr::case_when(
    test_class == "serology" ~ bld$specimen_source_snomed,
    test_class == "antigen" ~ upper$specimen_source_snomed,
    TRUE ~ resp$specimen_source_snomed
  )
  specimen_source <- dplyr::case_when(
    test_class == "serology" ~ bld$specimen_source,
    test_class == "antigen" ~ upper$specimen_source,
    TRUE ~ resp$specimen_source
  )

  # -- the result -------------------------------------------------------------
  p_pos <- positivity[d_chr]
  # Antigen is less sensitive, so it detects less often on the same day;
  # serology positivity tracks cumulative infection, not current, so it runs
  # higher later in the series.
  p_pos <- dplyr::case_when(
    test_class == "antigen" ~ p_pos * 0.72,
    test_class == "serology" ~
      pmin(0.45, 0.03 + 0.0012 * as.numeric(collect_date - date_start)),
    TRUE ~ p_pos
  )

  r <- runif(n)
  # A small share of every feed is unusable: invalid runs, leaking tubes,
  # swabs that arrived warm.
  bad <- runif(n) < 0.018
  positive <- r < p_pos

  result_key <- dplyr::case_when(
    bad & runif(n) < 0.45 ~ "unsatisfactory",
    bad ~ "invalid",
    test_class == "serology" & positive ~ "positive",
    test_class == "serology" ~ "negative",
    positive ~ "detected",
    runif(n) < 0.012 ~ "inconclusive",
    TRUE ~ "not_detected"
  )
  result_value <- dplyr::recode(
    result_key,
    detected = "Detected",
    not_detected = "Not detected",
    inconclusive = "Inconclusive",
    invalid = "Invalid result",
    unsatisfactory = "Specimen unsatisfactory for evaluation",
    positive = "Positive",
    negative = "Negative",
    indeterminate = "Indeterminate"
  )
  result_snomed <- unname(snomed_result[result_key])

  # Serology reports a numeric index alongside the interpretation.
  sero_index <- ifelse(
    test_class == "serology",
    round(
      ifelse(
        result_key == "positive",
        rgamma(n, shape = 3, scale = 2.2) + 1.4,
        rgamma(n, shape = 1.2, scale = 0.35)
      ),
      2
    ),
    NA_real_
  )
  result_units <- ifelse(test_class == "serology", "index", NA_character_)
  reference_range <- dplyr::case_when(
    test_class == "serology" ~ "<1.40 index",
    TRUE ~ "Not detected"
  )

  # Cycle threshold is only meaningful for a positive amplification test, and
  # plenty of labs never reported it at all.
  ct_value <- ifelse(
    test_class == "pcr" & result_key == "detected" & runif(n) < 0.62,
    round(pmin(pmax(rnorm(n, 24, 5.5), 12), 38), 1),
    NA_real_
  )

  abnormal_flag <- dplyr::case_when(
    result_key %in% c("detected", "positive") ~ "A",
    result_key %in% c("not_detected", "negative") ~ "N",
    TRUE ~ NA_character_
  )
  # HL7 OBX-11. Preliminary results get corrected later — see the resend block.
  result_status <- sample(
    c("F", "P"),
    n,
    replace = TRUE,
    prob = c(0.94, 0.06)
  )

  # -- diagnosis codes, by era ------------------------------------------------
  era <- dplyr::case_when(
    collect_date < as.Date("2020-04-01") ~ 1L,
    collect_date < as.Date("2021-01-01") ~ 2L,
    TRUE ~ 3L
  )
  draw_dx <- function(k) {
    out <- character(n)
    i1 <- era == 1L
    i2 <- era == 2L
    i3 <- era == 3L
    out[i1] <- wsample(icd_era1, sum(i1), icd_era1_prob)
    out[i2] <- wsample(icd_era2, sum(i2), icd_era2_prob)
    out[i3] <- wsample(icd_era3, sum(i3), icd_era3_prob)
    out
  }
  dx1 <- draw_dx(1)
  dx2 <- ifelse(runif(n) < 0.38, draw_dx(2), NA_character_)
  dx3 <- ifelse(runif(n) < 0.11, draw_dx(3), NA_character_)
  dx_codes <- mapply(
    function(a, b, c) paste(unique(stats::na.omit(c(a, b, c))), collapse = "|"),
    dx1,
    dx2,
    dx3,
    USE.NAMES = FALSE
  )
  # Some senders strip the decimal point. This is real, it is annoying, and it
  # is why a join on raw code strings fails.
  strip <- runif(n) < 0.04
  dx_codes[strip] <- gsub(".", "", dx_codes[strip], fixed = TRUE)

  # -- provider and facility --------------------------------------------------
  # Issued NPIs start with 1 or 2; the remaining eight digits are free.
  npi_base <- sample(c(100000000, 200000000), n, replace = TRUE) +
    sample.int(99999999, n, replace = TRUE)
  provider_last <- sample(surnames, n, replace = TRUE)
  provider_first <- sample(first_names, n, replace = TRUE)

  out <- tibble::tibble(
    message_control_id = sprintf("MSG%011.0f", 20200000000 + seq_no),
    accession_number = accession_number,
    specimen_id = specimen_id,
    placer_order_number = sprintf("PLC%09.0f", 500000 + seq_no * 3),
    filler_order_number = paste0(lab$id_prefix, sprintf("F%08.0f", seq_no)),

    patient_id = sprintf("PT%08d", pid),
    patient_last_name = keyed_pick(pid, 13, surnames),
    patient_first_name = keyed_pick(pid, 17, first_names),
    date_of_birth = dob,
    sex = sex_raw,
    race = keyed_pick(
      pid,
      19,
      c(
        "White",
        "White",
        "White",
        "White",
        "Black or African American",
        "Black or African American",
        "Asian",
        "American Indian or Alaska Native",
        "Native Hawaiian or Other Pacific Islander",
        "Other Race",
        "Unknown"
      )
    ),
    ethnicity = keyed_pick(
      pid,
      23,
      c(
        "Not Hispanic or Latino",
        "Not Hispanic or Latino",
        "Not Hispanic or Latino",
        "Hispanic or Latino",
        "Unknown"
      )
    ),
    patient_town = town,
    patient_county = "Hartford",
    patient_state = "CT",
    patient_zip = sprintf("%05d", 6000 + (keyed_hash(pid, 29) %% 900)),

    ordering_facility = sample(ordering_facilities, n, replace = TRUE),
    ordering_provider_npi = npi_from_base(npi_base),
    ordering_provider_name = paste0(provider_last, ", ", provider_first),

    performing_lab = lab$performing_lab,
    performing_lab_clia = lab$performing_lab_clia,

    specimen_collection_dt = collect_dt,
    specimen_received_dt = received_dt,
    result_dt = result_dt,
    reported_to_dph_dt = reported_dt,

    specimen_source_snomed = specimen_source_snomed,
    specimen_source = specimen_source,

    test_ordered_loinc = test_ordered_loinc,
    test_ordered_name = test_ordered_name,
    test_performed_loinc = test_performed_loinc,
    test_performed_name = test_performed_name,
    test_method = test_method,
    instrument_model = instrument_model,

    result_snomed = result_snomed,
    result_value = result_value,
    result_numeric = sero_index,
    result_units = result_units,
    reference_range = reference_range,
    abnormal_flag = abnormal_flag,
    result_status = result_status,
    ct_value = ct_value,

    dx_codes = dx_codes,
    note = NA_character_,

    # Carried along so resends inherit the same sender profile, then dropped
    # before the chunk is written.
    .dt_style = lab$dt_style,
    .code_style = lab$code_style,
    .text_style = lab$text_style,
    .id_prefix = lab$id_prefix,
    .test_class = test_class
  )

  # -- deliberate messiness ---------------------------------------------------
  # None of this is decoration. Each pattern below shows up in real ELR feeds
  # and each one breaks a naive pipeline in a different way.

  # Case and whitespace drift in free-text-ish fields.
  jitter_case <- runif(n) < 0.05
  out$performing_lab[jitter_case] <- toupper(out$performing_lab[jitter_case])
  pad <- runif(n) < 0.03
  out$patient_town[pad] <- paste0(out$patient_town[pad], " ")

  # Missing values, concentrated where they really go missing.
  out$specimen_collection_dt[runif(n) < 0.015] <- as.POSIXct(NA)
  out$patient_zip[runif(n) < 0.02] <- NA_character_
  out$ordering_provider_npi[runif(n) < 0.025] <- NA_character_
  out$race[runif(n) < 0.09] <- "Unknown"
  out$ethnicity[runif(n) < 0.11] <- "Unknown"
  out$sex[runif(n) < 0.008] <- NA_character_

  # A sparse free-text comment field, because there is always one.
  has_note <- runif(n) < 0.04
  out$note[has_note] <- sample(
    c(
      "Specimen received at ambient temperature.",
      "Result called to ordering provider.",
      "Repeat testing recommended if clinically indicated.",
      "Inconclusive - insufficient volume for repeat.",
      "PATIENT REPORTS SYMPTOM ONSET 3 DAYS PRIOR",
      "duplicate order - see prior accession",
      "Test performed at reference laboratory.",
      "Sample leaked in transit; result may be unreliable."
    ),
    sum(has_note),
    replace = TRUE
  )

  # -- optional sender quirks (--messy), part 1 -------------------------------
  # These run BEFORE resends, so a re-transmitted message carries the same
  # town spelling and the same test code as the original — a resend is the
  # same message sent twice, not a second data-entry event.

  if ("towns" %in% messy_parts) {
    # A patient's actual address is fixed; only the spelling wobbles.
    away <- keyed_unif(pid, 31) < 0.02
    if (any(away)) {
      j <- 1 + floor(keyed_unif(pid[away], 37) * nrow(out_of_area))
      out$patient_town[away] <- out_of_area$town[j]
      out$patient_county[away] <- out_of_area$county[j]
      out$patient_state[away] <- out_of_area$state[j]
      # An out-of-state ZIP no longer starts with 0-6xxx.
      out$patient_zip[away] <- sprintf(
        "%05d",
        ifelse(
          out_of_area$state[j] == "MA",
          1001 + (keyed_hash(pid[away], 41) %% 1000),
          ifelse(
            out_of_area$state[j] == "RI",
            2801 + (keyed_hash(pid[away], 43) %% 100),
            6000 + (keyed_hash(pid[away], 47) %% 900)
          )
        )
      )
    }
    out$patient_town <- messy_town(out$patient_town)
    # State arrives in whatever case the registration screen allowed.
    st <- runif(n) < 0.06
    out$patient_state[st] <- tolower(out$patient_state[st])
    st <- runif(n) < 0.03
    out$patient_state[st] <- c(
      CT = "Connecticut",
      MA = "Massachusetts",
      RI = "Rhode Island"
    )[toupper(out$patient_state[st])]
  }

  if ("codes" %in% messy_parts) {
    # Local codes until the sender finishes LOINC onboarding, LOINC after.
    # The cutover is the sender's, not the pandemic's, so it lands mid-series.
    pre_onboarding <- out$.code_style == "local" &
      !is.na(collect_date) &
      collect_date < as.Date("2020-09-01")
    if (any(pre_onboarding)) {
      lc <- local_test_code(
        out$.id_prefix[pre_onboarding],
        out$.test_class[pre_onboarding]
      )
      out$test_performed_loinc[pre_onboarding] <- lc
      out$test_ordered_loinc[pre_onboarding] <- lc
    }
  }

  # Resends and corrections. The same specimen comes back with a new message
  # id, a later result timestamp, status C, and sometimes a changed result.
  # Deduplicating on specimen_id alone throws away the correction; keeping
  # everything double-counts. That tension is the lesson.
  n_resend <- round(n * 0.017)
  if (n_resend > 0) {
    idx <- sample.int(n, n_resend)
    resend <- out[idx, ]
    resend$message_control_id <- sprintf(
      "MSG%011.0f",
      90200000000 + seq_len(n_resend) + offset
    )
    resend$result_status <- "C"
    resend$result_dt <- resend$result_dt + rexp(n_resend, 1 / (36 * 3600))
    resend$reported_to_dph_dt <- resend$result_dt +
      rexp(n_resend, 1 / (6 * 3600))
    flip <- runif(n_resend) < 0.22
    resend$result_value[flip] <- ifelse(
      resend$result_value[flip] == "Detected",
      "Not detected",
      "Detected"
    )
    resend$result_snomed[flip] <- ifelse(
      resend$result_value[flip] == "Detected",
      snomed_result[["detected"]],
      snomed_result[["not_detected"]]
    )
    resend$note[flip] <- "CORRECTED REPORT - supersedes previous result."
    out <- dplyr::bind_rows(out, resend)
  }

  # -- optional sender quirks (--messy), part 2 -------------------------------
  # These run AFTER resends, because a correction must be written in the same
  # dialect as the message it corrects, using its own later timestamp.

  if ("text" %in% messy_parts) {
    out$result_value <- drift_result_text(
      out$result_value,
      out$.text_style,
      out$test_method
    )
    # And sometimes the coded result is simply absent, leaving the free text
    # as the only thing to go on.
    out$result_snomed[runif(nrow(out)) < 0.08] <- NA_character_
  }

  if ("dates" %in% messy_parts) {
    for (col in c(
      "specimen_collection_dt",
      "specimen_received_dt",
      "result_dt",
      "reported_to_dph_dt"
    )) {
      out[[col]] <- format_dt(out[[col]], out$.dt_style)
    }
  }

  out <- dplyr::select(out, -dplyr::starts_with("."))

  # Feeds do not arrive sorted.
  out[sample.int(nrow(out)), ]
}

# --- 6. Write, in chunks -----------------------------------------------------

started <- Sys.time()
if (!dir.exists(dirname(out_path))) {
  dir.create(dirname(out_path), recursive = TRUE)
}

if (identical(out_format, "csv")) {
  if (file.exists(out_path)) {
    file.remove(out_path)
  }
  written <- 0
  offset <- 0
  while (offset < n_rows) {
    this_n <- min(chunk_size, n_rows - offset)
    chunk <- make_chunk(this_n, offset)
    readr::write_csv(
      chunk,
      out_path,
      append = offset > 0,
      col_names = offset == 0,
      na = ""
    )
    written <- written + nrow(chunk)
    offset <- offset + this_n
    cat(sprintf(
      "  %s rows written (%.0f%%)\n",
      format(written, big.mark = ","),
      100 * offset / n_rows
    ))
  }
} else if (identical(out_format, "parquet")) {
  rlang::check_installed("arrow", reason = "to write parquet")
  # Same chunking, one parquet file per chunk in a directory — the layout
  # arrow::open_dataset() expects.
  dir.create(out_path, recursive = TRUE, showWarnings = FALSE)
  written <- 0
  offset <- 0
  part <- 0
  while (offset < n_rows) {
    this_n <- min(chunk_size, n_rows - offset)
    chunk <- make_chunk(this_n, offset)
    arrow::write_parquet(
      chunk,
      file.path(out_path, sprintf("part-%04d.parquet", part))
    )
    written <- written + nrow(chunk)
    offset <- offset + this_n
    part <- part + 1
  }
} else {
  stop("--format must be 'csv' or 'parquet', got '", out_format, "'")
}

# --- 7. Validation summary (printed, not saved) ------------------------------

elapsed <- as.numeric(difftime(Sys.time(), started, units = "secs"))
cat("\n--- synthetic COVID-19 lab results ---\n")
cat("Rows written:", format(written, big.mark = ","), "\n")
cat("Wrote:", out_path, "\n")
if (identical(out_format, "csv")) {
  cat(sprintf("Size on disk: %.1f MB\n", file.size(out_path) / 1024^2))
}
cat(sprintf("Elapsed: %.1f sec\n", elapsed))
cat(
  "Messy layers:",
  if (length(messy_parts) == 0) "none" else paste(messy_parts, collapse = ", "),
  "\n"
)

# Re-read a sample to sanity-check the era switch actually shows up.
# Note what this summary has to do to survive --messy: the era table can only
# be built when the timestamps are still parseable, and positivity has to be
# counted off the SNOMED code rather than the result text. Both are exactly
# the accommodations a reader ends up making.
if (identical(out_format, "csv") && written <= 2e6) {
  check <- readr::read_csv(
    out_path,
    show_col_types = FALSE,
    progress = FALSE,
    col_types = readr::cols(specimen_collection_dt = readr::col_character())
  )
  if ("dates" %in% messy_parts) {
    cat("(era table skipped: --messy dates makes the timestamps unparseable\n")
    cat(" without per-sender handling, which is the point of that layer)\n")
  } else {
    eras <- check |>
      mutate(
        d = as.Date(specimen_collection_dt),
        era = case_when(
          is.na(d) ~ "missing date",
          d < as.Date("2020-04-01") ~ "1: pre-U07.1",
          d < as.Date("2021-01-01") ~ "2: U07.1 live",
          TRUE ~ "3: Z20.822 batch live"
        ),
        has_u071 = str_detect(dx_codes, "U07\\.?1")
      ) |>
      count(era, has_u071)
    print(eras)
  }
  cat(sprintf(
    "Overall positivity (by SNOMED): %.1f%%\n",
    100 *
      mean(check$result_snomed %in% c("260373001", "10828004"), na.rm = TRUE)
  ))
  cat(sprintf(
    "Corrected reports: %s\n",
    format(sum(check$result_status == "C"), big.mark = ",")
  ))
  cat(sprintf(
    "Distinct patients: %s across %s results\n",
    format(dplyr::n_distinct(check$patient_id), big.mark = ","),
    format(nrow(check), big.mark = ",")
  ))
}
