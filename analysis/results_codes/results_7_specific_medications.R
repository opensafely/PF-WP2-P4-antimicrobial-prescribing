
# ==============================================================================
# PHARMACY FIRST: FIRST- AND SECOND-LINE ANTIBIOTIC PRESCRIBING
# By setting (GP/PF), condition and antibiotic
#
# Statistical Disclosure Control (SDC):
#   0       = retained
#   1–7     = suppressed
#   >= 8    = rounded to nearest 5 (conventional half-up rounding)
#
# GP: SDC throughout the study period
# PF: SDC from February 2024 onwards
# ==============================================================================

# 1. PACKAGES ------------------------------------------------------------------

library(dplyr)
library(tidyr)
library(ggplot2)
library(readr)
library(here)
library(grid)
library(lubridate)

# 2. DATA AND DATES ------------------------------------------------------------

practice_level_data_by_practice_only <- read_csv(
  here("output", "practice_level_data_by_practice_only.csv"),
  show_col_types = FALSE
) %>%
  mutate(
    interval_start = as.Date(interval_start)
  )

# Reference dates
GP_connect <- as.Date("2025-10-01")
PF_start   <- as.Date("2024-02-01")

# SDC parameters
SDC_THRESHOLD <- 8
SDC_PF_START  <- as.Date("2024-02-01")

# Output directory
output_dir <- here(
  "output",
  "first_second_line_medication"
)

dir.create(
  output_dir,
  recursive = TRUE,
  showWarnings = FALSE
)

# 3. DATE DIAGNOSTICS ----------------------------------------------------------

cat("\nDATE DIAGNOSTICS\n")

print(
  practice_level_data_by_practice_only %>%
    summarise(
      total_rows = n(),
      missing_dates = sum(is.na(interval_start)),
      valid_dates = sum(!is.na(interval_start)),
      first_date = min(interval_start, na.rm = TRUE),
      last_date = max(interval_start, na.rm = TRUE)
    )
)

# Stop if there are no valid dates
if (all(is.na(practice_level_data_by_practice_only$interval_start))) {
  stop("No valid interval_start dates found in the input dataset.")
}

# 4. STATISTICAL DISCLOSURE CONTROL --------------------------------------------

# Identify records subject to SDC
is_sdc_applicable <- function(setting, interval_start) {

  setting == "GP" |
    (
      setting == "PF" &
        !is.na(interval_start) &
        interval_start >= SDC_PF_START
    )
}

# Conventional rounding to nearest 5 (half-up)
round_nearest_5 <- function(x) {
  floor(as.numeric(x) / 5 + 0.5) * 5
}

# 4A. SDC for plots
# Counts 1–7 are suppressed.
# Counts >=8 are rounded to nearest 5.
# Zero counts are retained.

apply_sdc_plot <- function(data) {

  data %>%
    mutate(
      sdc_required = !is.na(count) &
        count > 0 &
        count < SDC_THRESHOLD &
        is_sdc_applicable(setting, interval_start),

      count_plot = case_when(

        # Suppress counts 1–7
        sdc_required ~ NA_real_,

        # Round counts >=8
        !is.na(count) &
          count >= SDC_THRESHOLD &
          is_sdc_applicable(setting, interval_start) ~
          round_nearest_5(count),

        # Retain zero and values outside the SDC period
        TRUE ~ as.numeric(count)
      )
    )
}

# 4B. SDC for released CSV files
# Counts 1–7 = [Redacted]
# Counts >=8 = rounded to nearest 5
# Zero = 0

apply_sdc_release <- function(data) {

  data %>%
    mutate(
      count = case_when(

        is.na(count) ~ NA_character_,

        # Suppress counts 1–7
        count > 0 &
          count < SDC_THRESHOLD &
          is_sdc_applicable(setting, interval_start) ~
          "[Redacted]",

        # Round counts >=8
        count >= SDC_THRESHOLD &
          is_sdc_applicable(setting, interval_start) ~
          as.character(round_nearest_5(count)),

        # Retain zero and values outside the SDC period
        TRUE ~ as.character(count)
      )
    ) %>%
    select(
      -any_of(c("sdc_required", "count_plot"))
    )
}

# 5. PLOT THEME ----------------------------------------------------------------

antibiotic_theme <- theme_bw() +
  theme(
    legend.position = "bottom",
    axis.text.x = element_text(
      angle = 45,
      hjust = 1
    ),
    legend.text = element_text(size = 8),
    legend.key.size = unit(0.4, "cm")
  )

# 6. ANTIBIOTIC PLOTTING FUNCTION ----------------------------------------------

make_antibiotic_plot <- function(data, plot_title) {

  # Exclude missing dates from plotting
  valid_dates <- data %>%
    filter(!is.na(interval_start))

  if (nrow(valid_dates) == 0) {
    stop(
      paste(
        "No valid dates available for:",
        plot_title
      )
    )
  }

  ggplot(
    valid_dates,
    aes(
      x = interval_start,
      y = count_plot,
      fill = antibiotic
    )
  ) +

    geom_col(
      position = "stack",
      na.rm = TRUE
    ) +

    geom_vline(
      xintercept = GP_connect,
      linetype = "dashed",
      colour = "blue",
      linewidth = 0.3
    ) +

    geom_vline(
      xintercept = PF_start,
      linetype = "dashed",
      colour = "black",
      linewidth = 0.3
    ) +

    scale_x_date(
      date_labels = "%Y-%m",
      date_breaks = "1 month"
    ) +

    labs(
      title = plot_title,
      x = "Month",
      y = "Number of prescriptions",
      fill = "Antibiotic"
    ) +

    antibiotic_theme +

    guides(
      fill = guide_legend(
        nrow = 1,
        title.position = "left"
      )
    )
}

# 7. SAVE PNG AND SDC-PROTECTED CSV --------------------------------------------

save_antibiotic_outputs <- function(data, plot, filename) {

  # Save PNG
  ggsave(
    filename = file.path(
      output_dir,
      paste0(filename, ".png")
    ),
    plot = plot,
    width = 10,
    height = 6,
    dpi = 300
  )

  # Save SDC-protected CSV
  readr::write_csv(
    data %>%
      arrange(
        interval_start,
        antibiotic
      ) %>%
      apply_sdc_release(),

    file.path(
      output_dir,
      paste0(filename, ".csv")
    )
  )
}

# 8. EXTRACT ANTIBIOTIC VARIABLES ----------------------------------------------

antibiotic_data <- practice_level_data_by_practice_only %>%

  select(
    practice,
    interval_start,
    matches(
      "^(pf|gp)_.*_(uti|sinusitis|insectbite|otitismedia|sorethroat|shingles|impetigo)$"
    )
  ) %>%

  pivot_longer(
    cols = -c(practice, interval_start),
    names_to = "measure",
    values_to = "count"
  ) %>%

  # Exclude consultations and medication totals
  filter(
    !grepl(
      "^(pf|gp)_(consultation|medication)_",
      measure
    )
  ) %>%

  mutate(
    setting = if_else(
      grepl("^pf_", measure),
      "PF",
      "GP"
    ),

    antibiotic = sub(
      "^(pf|gp)_",
      "",
      measure
    ),

    condition_code = sub(
      ".*_(uti|sinusitis|insectbite|otitismedia|sorethroat|shingles|impetigo)$",
      "\\1",
      measure
    ),

    condition = recode(
      condition_code,
      uti = "UTI",
      sinusitis = "Sinusitis",
      insectbite = "Insect bites",
      otitismedia = "Otitis media",
      sorethroat = "Sore throat",
      shingles = "Shingles",
      impetigo = "Impetigo"
    ),

    antibiotic = sub(
      "_(uti|sinusitis|insectbite|otitismedia|sorethroat|shingles|impetigo)$",
      "",
      antibiotic
    ),

    antibiotic = tools::toTitleCase(
      gsub("_", " ", antibiotic)
    ),

    count = as.numeric(count)
  )

# 9. OVERALL ANTIBIOTIC COUNTS ACROSS CONDITIONS -------------------------------

antibiotic_monthly <- antibiotic_data %>%

  group_by(
    interval_start,
    setting,
    antibiotic
  ) %>%

  summarise(
    count = sum(count, na.rm = TRUE),
    .groups = "drop"
  ) %>%

  apply_sdc_plot()

# 9A. Overall GP plot

gp_antibiotics_plot <- antibiotic_monthly %>%
  filter(setting == "GP") %>%
  make_antibiotic_plot(
    "A. GP antibiotic prescribing across conditions"
  )

print(gp_antibiotics_plot)

save_antibiotic_outputs(
  antibiotic_monthly %>%
    filter(setting == "GP"),
  gp_antibiotics_plot,
  "results_7_medications_gp"
)

# 9B. Overall PF plot

pf_antibiotics_plot <- antibiotic_monthly %>%
  filter(setting == "PF") %>%
  make_antibiotic_plot(
    "B. PF antibiotic prescribing across conditions"
  )

print(pf_antibiotics_plot)

save_antibiotic_outputs(
  antibiotic_monthly %>%
    filter(setting == "PF"),
  pf_antibiotics_plot,
  "results_7_medications_pf"
)

# 10. MEDICATION COUNTS BY INDIVIDUAL CONDITION -------------------------------

medication_monthly <- antibiotic_data %>%

  group_by(
    interval_start,
    setting,
    condition,
    antibiotic
  ) %>%

  summarise(
    count = sum(count, na.rm = TRUE),
    .groups = "drop"
  ) %>%

  apply_sdc_plot()

# 11. ALL CONDITIONS DATA ------------------------------------------------------

all_conditions_data <- antibiotic_monthly %>%
  mutate(
    condition = "All conditions"
  )

# Combine individual conditions and all-conditions aggregate

all_plot_data <- bind_rows(
  medication_monthly,
  all_conditions_data
)

# 12. SEPARATE GP AND PF PLOTS BY CONDITION ------------------------------------

condition_names <- c(
  "UTI" = "uti",
  "Sinusitis" = "sinusitis",
  "Insect bites" = "insectbite",
  "Otitis media" = "otitismedia",
  "Sore throat" = "sorethroat",
  "Shingles" = "shingles",
  "Impetigo" = "impetigo",
  "All conditions" = "all"
)

for (condition_name in names(condition_names)) {

  condition_suffix <- unname(
    condition_names[[condition_name]]
  )

  # ---------------------------------------------------------------------------
  # A. GENERAL PRACTICE
  # ---------------------------------------------------------------------------

  gp_data <- all_plot_data %>%
    filter(
      setting == "GP",
      condition == condition_name
    )

  if (nrow(gp_data) > 0) {

    gp_condition_plot <- make_antibiotic_plot(
      gp_data,
      paste0(
        "GP antibiotic prescribing for ",
        condition_name
      )
    )

    print(gp_condition_plot)

    gp_filename <- paste0(
      "gp_antibiotics_by_condition_",
      condition_suffix
    )

    save_antibiotic_outputs(
      gp_data,
      gp_condition_plot,
      gp_filename
    )
  }

  # ---------------------------------------------------------------------------
  # B. PHARMACY FIRST
  # ---------------------------------------------------------------------------

  pf_data <- all_plot_data %>%
    filter(
      setting == "PF",
      condition == condition_name
    )

  if (nrow(pf_data) > 0) {

    pf_condition_plot <- make_antibiotic_plot(
      pf_data,
      paste0(
        "Pharmacy First antibiotic prescribing for ",
        condition_name
      )
    )

    print(pf_condition_plot)

    pf_filename <- paste0(
      "pf_antibiotics_by_condition_",
      condition_suffix
    )

    save_antibiotic_outputs(
      pf_data,
      pf_condition_plot,
      pf_filename
    )
  }
}

# 13. SDC AUDIT ----------------------------------------------------------------

cat("\n========================================\n")
cat("STATISTICAL DISCLOSURE CONTROL AUDIT\n")
cat("========================================\n")

# Overall antibiotic counts

cat("\nSDC audit: overall antibiotic counts\n")

print(
  antibiotic_monthly %>%
    filter(sdc_required) %>%
    count(
      setting,
      name = "n_suppressed"
    )
)

# Condition-specific medication counts

cat("\nSDC audit: condition-specific medication counts\n")

print(
  medication_monthly %>%
    filter(sdc_required) %>%
    count(
      setting,
      condition,
      name = "n_suppressed"
    )
)

# All-conditions counts

cat("\nSDC audit: all-conditions counts\n")

print(
  all_conditions_data %>%
    filter(sdc_required) %>%
    count(
      setting,
      name = "n_suppressed"
    )
)

# 14. OUTPUT SUMMARY -----------------------------------------------------------

cat("\n========================================\n")
cat("OUTPUT GENERATION COMPLETED\n")
cat("========================================\n")

cat("\nOutput directory:\n")
cat(output_dir, "\n")

cat("\nSDC rules applied:\n")
cat("Counts 0: retained\n")
cat("Counts 1-7: suppressed\n")
cat("Counts >=8: rounded to nearest 5\n")
cat("GP: throughout the study period\n")
cat("PF: from February 2024 onwards\n")

#cat("\n========================================\n")

