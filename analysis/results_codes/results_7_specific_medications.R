# =============================================================================
# Pharmacy First: antibiotic prescribing by setting and condition
# Statistical Disclosure Control (SDC)
# Output directory: output/first_second_line_medication/
# =============================================================================

# 1. Packages
library(dplyr)
library(tidyr)
library(ggplot2)
library(readr)
library(here)
library(grid)

# =============================================================================
# 2. Read data and define dates
# =============================================================================

practice_level_data_by_practice_only <- read_csv(
  here("output", "practice_level_data_by_practice_only.csv"),
  show_col_types = FALSE
) %>%
  mutate(interval_start = as.Date(interval_start)) %>%
  filter(interval_start <= as.Date("2026-02-01"))

# Plot reference dates
GP_connect <- as.Date("2025-10-01")
PF_start   <- as.Date("2022-02-01")

# SDC dates and threshold
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

# =============================================================================
# 3. Statistical Disclosure Control functions
# =============================================================================

# GP: suppress counts < 8 throughout the period.
# PF: suppress counts < 8 from February 2024 onwards.

apply_sdc_plot <- function(data) {
  data %>%
    mutate(
      sdc_required = !is.na(count) &
        count < SDC_THRESHOLD &
        (
          setting == "GP" |
            (
              setting == "PF" &
                interval_start >= SDC_PF_START
            )
        ),
      count_plot = if_else(
        sdc_required,
        NA_real_,
        as.numeric(count)
      )
    )
}

# Protect counts in CSV files.
apply_sdc_release <- function(data) {
  data %>%
    mutate(
      count = if_else(
        !is.na(count) &
          count < SDC_THRESHOLD &
          (
            setting == "GP" |
              (
                setting == "PF" &
                  interval_start >= SDC_PF_START
              )
          ),
        "[Redacted]",
        as.character(count)
      )
    ) %>%
    select(-any_of(c("sdc_required", "count_plot")))
}

# =============================================================================
# 4. Common plotting functions
# =============================================================================

antibiotic_theme <- theme_bw() +
  theme(
    legend.position = "bottom",
    axis.text.x = element_text(angle = 45, hjust = 1),
    legend.text = element_text(size = 8),
    legend.key.size = unit(0.4, "cm"),
    strip.text = element_text(face = "bold")
  )

# Plot for overall or individual-condition data.
make_antibiotic_plot <- function(data, plot_title) {

  ggplot(
    data,
    aes(
      x = interval_start,
      y = count_plot,
      fill = antibiotic
    )
  ) +
    geom_area(
      position = "stack",
      na.rm = TRUE
    ) +
    geom_vline(
      xintercept = GP_connect,
      linetype = "dashed",
      colour = "blue",
      linewidth = 0.8
    ) +
    geom_vline(
      xintercept = PF_start,
      linetype = "dashed",
      colour = "black",
      linewidth = 0.8
    ) +
    scale_x_date(
      date_labels = "%Y-%m",
      date_breaks = "2 months"
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

# Combined plot showing separate panels for each condition.
make_combined_condition_plot <- function(data, plot_title) {

  ggplot(
    data,
    aes(
      x = interval_start,
      y = count_plot,
      fill = antibiotic
    )
  ) +
    geom_area(
      position = "stack",
      na.rm = TRUE
    ) +
    geom_vline(
      xintercept = GP_connect,
      linetype = "dashed",
      colour = "blue",
      linewidth = 0.6
    ) +
    geom_vline(
      xintercept = PF_start,
      linetype = "dashed",
      colour = "black",
      linewidth = 0.6
    ) +
    facet_wrap(
      ~ condition,
      scales = "free_y"
    ) +
    scale_x_date(
      date_labels = "%Y-%m",
      date_breaks = "4 months"
    ) +
    labs(
      title = plot_title,
      x = "Month",
      y = "Number of prescriptions",
      fill = "Antibiotic"
    ) +
    antibiotic_theme +
    theme(
      legend.position = "bottom",
      axis.text.x = element_text(
        angle = 45,
        hjust = 1,
        size = 7
      )
    ) +
    guides(
      fill = guide_legend(
        nrow = 2,
        title.position = "left"
      )
    )
}

# =============================================================================
# 5. Common save function for PNG and SDC-protected CSV
# =============================================================================

save_antibiotic_outputs <- function(data, plot, filename) {

  png_path <- file.path(
    output_dir,
    paste0(filename, ".png")
  )

  csv_path <- file.path(
    output_dir,
    paste0(filename, ".csv")
  )

  # Save PNG
  ggsave(
    filename = png_path,
    plot = plot,
    width = 12,
    height = 7,
    dpi = 300,
    bg = "white"
  )

  # Save SDC-protected CSV
  data_to_release <- data %>%
    arrange(interval_start, antibiotic) %>%
    apply_sdc_release()

  write_csv(
    data_to_release,
    csv_path
  )

  message("Saved: ", png_path)
  message("Saved: ", csv_path)

  invisible(
    list(
      png = png_path,
      csv = csv_path
    )
  )
}

# =============================================================================
# 6. Extract antibiotic variables
# =============================================================================

condition_pattern <- paste(
  c(
    "uti",
    "sinusitis",
    "insectbite",
    "otitismedia",
    "sorethroat",
    "shingles",
    "impetigo"
  ),
  collapse = "|"
)

antibiotic_data <- practice_level_data_by_practice_only %>%
  select(
    practice,
    interval_start,
    matches(
      paste0(
        "^(pf|gp)_.*_(",
        condition_pattern,
        ")$"
      )
    )
  )

# Stop early if the expected medication columns were not found.
medication_columns <- setdiff(
  names(antibiotic_data),
  c("practice", "interval_start")
)

if (length(medication_columns) == 0) {
  stop(
    "No antibiotic columns were found. Check the column names in ",
    "practice_level_data_by_practice_only.csv."
  )
}

antibiotic_data <- antibiotic_data %>%
  pivot_longer(
    cols = all_of(medication_columns),
    names_to = "measure",
    values_to = "count"
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
      paste0(
        ".*_(",
        condition_pattern,
        ")$"
      ),
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
      paste0(
        "_(",
        condition_pattern,
        ")$"
      ),
      "",
      antibiotic
    ),
    antibiotic = tools::toTitleCase(
      gsub("_", " ", antibiotic)
    ),
    count = as.numeric(count)
  )

# =============================================================================
# 7. Overall monthly antibiotic counts
# =============================================================================

antibiotic_monthly <- antibiotic_data %>%
  group_by(
    interval_start,
    setting,
    antibiotic
  ) %>%
  summarise(
    count = if (all(is.na(count))) {
      NA_real_
    } else {
      sum(count, na.rm = TRUE)
    },
    .groups = "drop"
  ) %>%
  apply_sdc_plot()

# -----------------------------------------------------------------------------
# 7A. Overall GP
# -----------------------------------------------------------------------------

gp_antibiotics_data <- antibiotic_monthly %>%
  filter(setting == "GP")

gp_antibiotics_plot <- make_antibiotic_plot(
  gp_antibiotics_data,
  "A. GP antibiotic prescribing across conditions"
)

save_antibiotic_outputs(
  gp_antibiotics_data,
  gp_antibiotics_plot,
  "results_7_medications_gp"
)

# -----------------------------------------------------------------------------
# 7B. Overall Pharmacy First
# -----------------------------------------------------------------------------

pf_antibiotics_data <- antibiotic_monthly %>%
  filter(setting == "PF")

pf_antibiotics_plot <- make_antibiotic_plot(
  pf_antibiotics_data,
  "B. Pharmacy First antibiotic prescribing across conditions"
)

save_antibiotic_outputs(
  pf_antibiotics_data,
  pf_antibiotics_plot,
  "results_7_medications_pf"
)

# =============================================================================
# 8. Monthly medication counts by condition
# =============================================================================

medication_monthly <- antibiotic_data %>%
  group_by(
    interval_start,
    setting,
    condition,
    antibiotic
  ) %>%
  summarise(
    count = if (all(is.na(count))) {
      NA_real_
    } else {
      sum(count, na.rm = TRUE)
    },
    .groups = "drop"
  ) %>%
  apply_sdc_plot()

# =============================================================================
# 9. Combined condition plots and CSVs
# =============================================================================

gp_by_condition_data <- medication_monthly %>%
  filter(setting == "GP")

gp_by_condition_plot <- make_combined_condition_plot(
  gp_by_condition_data,
  "GP antibiotic prescribing by condition"
)

save_antibiotic_outputs(
  gp_by_condition_data,
  gp_by_condition_plot,
  "results_7_medications_gp_by_condition"
)

pf_by_condition_data <- medication_monthly %>%
  filter(setting == "PF")

pf_by_condition_plot <- make_combined_condition_plot(
  pf_by_condition_data,
  "Pharmacy First antibiotic prescribing by condition"
)

save_antibiotic_outputs(
  pf_by_condition_data,
  pf_by_condition_plot,
  "results_7_medications_pf_by_condition"
)

# =============================================================================
# 10. Individual condition outputs, including all conditions
# =============================================================================

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

# "All conditions" uses the overall aggregate, not a second sum of
# condition-level aggregates.
all_conditions_data <- antibiotic_monthly %>%
  mutate(condition = "All conditions")

all_plot_data <- bind_rows(
  medication_monthly,
  all_conditions_data
)

for (condition_name in names(condition_names)) {

  condition_suffix <- unname(
    condition_names[[condition_name]]
  )

  # ---------------------------------------------------------------------------
  # GP output
  # ---------------------------------------------------------------------------

  gp_data <- all_plot_data %>%
    filter(
      setting == "GP",
      condition == condition_name
    )

  gp_filename <- paste0(
    "gp_antibiotics_by_condition_",
    condition_suffix
  )

  gp_condition_plot <- make_antibiotic_plot(
    gp_data,
    paste0(
      "GP antibiotic prescribing: ",
      condition_name
    )
  )

  save_antibiotic_outputs(
    gp_data,
    gp_condition_plot,
    gp_filename
  )

  # ---------------------------------------------------------------------------
  # Pharmacy First output
  # ---------------------------------------------------------------------------

  pf_data <- all_plot_data %>%
    filter(
      setting == "PF",
      condition == condition_name
    )

  pf_filename <- paste0(
    "pf_antibiotics_by_condition_",
    condition_suffix
  )

  pf_condition_plot <- make_antibiotic_plot(
    pf_data,
    paste0(
      "Pharmacy First antibiotic prescribing: ",
      condition_name
    )
  )

  save_antibiotic_outputs(
    pf_data,
    pf_condition_plot,
    pf_filename
  )
}

# =============================================================================
# 11. SDC audit summaries
# =============================================================================

cat("\nSDC audit: overall monthly counts\n")

print(
  antibiotic_monthly %>%
    filter(sdc_required) %>%
    count(
      setting,
      name = "n_suppressed"
    )
)

cat("\nSDC audit: condition-specific monthly counts\n")

print(
  medication_monthly %>%
    filter(sdc_required) %>%
    count(
      setting,
      condition,
      name = "n_suppressed"
    )
)

cat("\nSDC audit: all-condition monthly counts\n")

print(
  all_conditions_data %>%
    filter(sdc_required) %>%
    count(
      setting,
      name = "n_suppressed"
    )
)

# =============================================================================
# 12. Verify expected output files
# =============================================================================

expected_filenames <- c(
  "results_7_medications_gp",
  "results_7_medications_pf",
  "results_7_medications_gp_by_condition",
  "results_7_medications_pf_by_condition",
  unlist(
    lapply(
      c("gp", "pf"),
      function(setting_prefix) {
        paste0(
          setting_prefix,
          "_antibiotics_by_condition_",
          unname(condition_names)
        )
      }
    )
  )
)

expected_files <- unlist(
  lapply(
    expected_filenames,
    function(filename) {
      file.path(
        output_dir,
        paste0(filename, c(".png", ".csv"))
      )
    }
  )
)

missing_files <- expected_files[
  !file.exists(expected_files)
]

cat(
  "\nExpected output files: ",
  length(expected_files),
  "\n",
  sep = ""
)

cat(
  "Files successfully created: ",
  sum(file.exists(expected_files)),
  "\n",
  sep = ""
)

if (length(missing_files) > 0) {

  cat("\nMissing output files:\n")
  print(missing_files)

  stop(
    "Some expected outputs were not generated. ",
    "Check the messages above and the job log."
  )

} else {

  cat(
    "\nAll 40 expected CSV and PNG files were generated.\n"
  )
}