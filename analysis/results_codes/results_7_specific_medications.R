

# Pharmacy First: antibiotic prescribing by setting and condition
# Statistical Disclosure Control (SDC)
# 1. Packages
library(dplyr)
library(tidyr)
library(ggplot2)
library(readr)
library(here)
library(grid)
# 2. Read data and define dates


practice_level_data_by_practice_only <- read_csv(
  here("output", "practice_level_data_by_practice_only.csv"),
  show_col_types = FALSE
) %>%
  mutate(interval_start = as.Date(interval_start)) %>%
  filter(interval_start <= as.Date("2026-02-01"))

# Reference dates
GP_connect <- as.Date("2025-10-01")
PF_start   <- as.Date("2022-02-01")

# SDC dates and threshold
SDC_THRESHOLD <- 8                     # Redacted if less or equal to 7
SDC_PF_START  <- as.Date("2024-02-01") # This will help to check small count in Post PF

# Output directory
# output_dir <- here("output")
output_dir <- here::here("output", "first_second_line_medication")

dir.create(
  output_dir,
  recursive = TRUE,
  showWarnings = FALSE
)

# 3. SDC functions
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

# Protection of  values in CSV files.
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

# Plot theme
antibiotic_theme <- theme_bw() +
  theme(
    legend.position = "bottom",
    axis.text.x = element_text(angle = 45, hjust = 1),
    legend.text = element_text(size = 8),
    legend.key.size = unit(0.4, "cm")
  )

# Plotting function
make_antibiotic_plot <- function(data, plot_title) {
  ggplot(
    data,
    aes(
      x = interval_start,
      y = count_plot,
      fill = antibiotic
    )
  ) +
    geom_area(position = "stack", na.rm = TRUE) +
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
      date_breaks = "1 month"
    ) +
    labs(
      title = plot_title,
      x = "Month",
      y = "Number of prescriptions",
      fill = "Antibiotic"
    ) +
    antibiotic_theme +
    guides(fill = guide_legend(nrow = 1, title.position = "left"))
}
# Function for CSV and PNG saving
save_antibiotic_outputs <- function(data, plot, filename) {

  # Save PNG
  ggsave(
    filename = file.path(output_dir, paste0(filename, ".png")),
    plot = plot,
    width = 10,
    height = 6,
    dpi = 300
  )

  # Save SDC-protected CSV
  readr::write_csv(
    data %>%
      arrange(interval_start, antibiotic) %>%
      apply_sdc_release(),
    file.path(output_dir, paste0(filename, ".csv"))
  )
}

# 4. Extract antibiotic variables

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
  mutate(
    setting = if_else(grepl("^pf_", measure), "PF", "GP"),
    antibiotic = sub("^(pf|gp)_", "", measure),
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
    antibiotic = tools::toTitleCase(gsub("_", " ", antibiotic))
  )


# 5. Overall antibiotic counts across conditions

# Aggregate across practices and conditions by month, setting and antibiotic.

antibiotic_monthly <- antibiotic_data %>%
  group_by(interval_start, setting, antibiotic) %>%
  summarise(
    count = sum(count, na.rm = TRUE),
    .groups = "drop"
  ) %>%
  apply_sdc_plot()

# Overall GP plot
gp_antibiotics_plot <- antibiotic_monthly %>%
  filter(setting == "GP") %>%
  make_antibiotic_plot("A. GP antibiotic prescribing across conditions")

print(gp_antibiotics_plot)

save_antibiotic_outputs(
  antibiotic_monthly %>% filter(setting == "GP"),
  gp_antibiotics_plot,
  "results_7_medications_gp"
)

# Overall PF plot
pf_antibiotics_plot <- antibiotic_monthly %>%
  filter(setting == "PF") %>%
  make_antibiotic_plot("B. PF antibiotic prescribing across conditions")

print(pf_antibiotics_plot)

save_antibiotic_outputs(
  antibiotic_monthly %>% filter(setting == "PF"),
  pf_antibiotics_plot,
  "results_7_medications_pf"
)


# 6. Medication counts by individual condition

medication_monthly <- antibiotic_data %>%
  group_by(interval_start, setting, condition, antibiotic) %>%
  summarise(
    count = sum(count, na.rm = TRUE),
    .groups = "drop"
  ) %>%
  apply_sdc_plot()


# 7. "all conditions" data

all_conditions_data <- antibiotic_monthly %>%
  mutate(condition = "All conditions")

# Combination individual-condition data and the overall aggregate.
all_plot_data <- bind_rows(
  medication_monthly,
  all_conditions_data
)
# 8. Separate GP and PF plots and CSVs for each condition, including all

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

  condition_suffix <- unname(condition_names[[condition_name]])

  
  # A.General practice
 
  gp_data <- all_plot_data %>%
    filter(
      setting == "GP",
      condition == condition_name
    )

  if (nrow(gp_data) > 0) {

    gp_condition_plot <- make_antibiotic_plot(
      gp_data,
      paste0("GP antibiotic prescribing: ", condition_name)
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

  
  # Pharmacy First
  
  pf_data <- all_plot_data %>%
    filter(
      setting == "PF",
      condition == condition_name
    )

  if (nrow(pf_data) > 0) {

    pf_condition_plot <- make_antibiotic_plot(
      pf_data,
      paste0("Pharmacy First antibiotic prescribing: ", condition_name)
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


# 9. SDC audit


cat("\nSDC audit: overall antibiotic counts\n")

print(
  antibiotic_monthly %>%
    filter(sdc_required) %>%
    count(setting, name = "n_suppressed")
)

cat("\nSDC audit: condition-specific medication counts\n")

print(
  medication_monthly %>%
    filter(sdc_required) %>%
    count(setting, condition, name = "n_suppressed")
)

cat("\nSDC audit: all-conditions counts\n")

print(
  all_conditions_data %>%
    filter(sdc_required) %>%
    count(setting, name = "n_suppressed")
)
