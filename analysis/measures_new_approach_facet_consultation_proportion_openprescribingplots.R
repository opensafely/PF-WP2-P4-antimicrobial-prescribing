# Monthly and annual medication counts by condition and setting

library(tidyverse)
library(here)
library(scales)
library(lubridate)
library(readr)

# 1. Data
practice_level_data_by_practice_only <- read_csv(
  here("output", "practice_level_data_by_practice_only.csv"),
  show_col_types = FALSE
) %>%
  mutate(
    interval_start = as.Date(interval_start)
  )

# Key intervention dates
GP_connect <- as.Date("2025-10-01")
PF_start   <- as.Date("2024-02-01")
#
data <- practice_level_data_by_practice_only %>%
  mutate(
    # General Practice
    gp_proportion_uti =
      100 * gp_medication_uti / gp_consultation_uti,
    
    gp_proportion_sinusitis =
      100 * gp_medication_sinusitis / gp_consultation_sinusitis,
    
    gp_proportion_insectbite =
      100 * gp_medication_insectbite / gp_consultation_insectbite,
    
    gp_proportion_otitismedia =
      100 * gp_medication_otitismedia / gp_consultation_otitismedia,
    
    gp_proportion_sorethroat =
      100 * gp_medication_sorethroat / gp_consultation_sorethroat,
    
    gp_proportion_shingles =
      100 * gp_medication_shingles / gp_consultation_shingles,
    
    gp_proportion_impetigo =
      100 * gp_medication_impetigo / gp_consultation_impetigo,
    
    gp_proportion_all_conditions =
      100 * gp_medication_all_conditions /
      gp_consultation_all_conditions,
    
    # Pharmacy First
    pf_proportion_uti =
      100 * pf_medication_uti / pf_consultation_uti,
    
    pf_proportion_sinusitis =
      100 * pf_medication_sinusitis / pf_consultation_sinusitis,
    
    pf_proportion_insectbite =
      100 * pf_medication_insectbite / pf_consultation_insectbite,
    
    pf_proportion_otitismedia =
      100 * pf_medication_otitismedia / pf_consultation_otitismedia,
    
    pf_proportion_sorethroat =
      100 * pf_medication_sorethroat / pf_consultation_sorethroat,
    
    pf_proportion_shingles =
      100 * pf_medication_shingles / pf_consultation_shingles,
    
    pf_proportion_impetigo =
      100 * pf_medication_impetigo / pf_consultation_impetigo,
    
    pf_proportion_all_conditions =
      100 * pf_medication_all_conditions /
      pf_consultation_all_conditions
  ) %>%
  select(
    practice,
    interval_start,
    #month,
    starts_with("gp_proportion_"),
    starts_with("pf_proportion_")
  )%>%
  arrange(practice,interval_start)

# 3. Long format

data_long <- data %>%
  pivot_longer(
    cols = starts_with("gp_proportion_") |
      starts_with("pf_proportion_"),
    names_to = c("setting", "condition"),
    names_pattern = "(gp|pf)_proportion_(.*)",
    values_to = "proportion"
  ) %>%
  mutate(
    setting = recode(
      setting,
      gp = "GP",
      pf = "PF"
    ),
    condition = recode(
      condition,
      uti = "UTI",
      sinusitis = "Sinusitis",
      insectbite = "Insect bites",
      otitismedia = "Otitis media",
      sorethroat = "Sore throat",
      shingles = "Shingles",
      impetigo = "Impetigo",
      all_conditions = "All conditions"
    )
  )