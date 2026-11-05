# =============================================================================
# Pharmacy First — measures_new_approach
# Monthly consultation counts (numerators) by condition and setting (GP vs PF),
# faceted by PF condition
# Author: Arnaud Iradukunda
# =============================================================================

library(tidyverse)
library(here)

# -----------------------------------------------------------------------------
# 1. Data
#    Output of generate_measures_new_approach_consultation, in long format:
#    measure, interval_start, interval_end, ratio, numerator, denominator
#    (plus any group_by columns, if added later)
# -----------------------------------------------------------------------------
measures_new_approach <- read_csv(
  here("output", "measures_new_approach_consultation.csv"),
  show_col_types = FALSE
) %>%
  mutate(interval_start = as.Date(interval_start))

# GP Connect date (vertical line)
GP_connect <- as.Date("2025-10-01")
PF_start <- as.Date("2024-02-01")


message("Number of rows: ", nrow(measures_new_approach))
message("Number of columns: ", ncol(measures_new_approach))

message(
  "Date range: ",
  min(measures_new_approach$interval_start, na.rm = TRUE),
  " to ",
  max(measures_new_approach$interval_start, na.rm = TRUE)
)

print(head(measures_new_approach))



# Conditions to include
conditions <- c(
  "uti",
  "sinusitis",
  "insectbite",
  "otitismedia",
  "sorethroat",
  "shingles",
  "impetigo",
  "all_conditions"
)

# -----------------------------------------------------------------------------
# 2. Monthly numerators by condition and setting
#    Summing by month and measure gives one total per month even if the
#    measures are later split by group_by (e.g. practice, age band).
# -----------------------------------------------------------------------------
numerators_monthly <- measures_new_approach %>%
  filter(
    str_detect(
      measure,
      paste0("^(gp|pf)_consultation_(", paste(conditions, collapse = "|"), ")$")
    )
  ) %>%
  group_by(interval_start, measure) %>%
  summarise(
    consultation_count = sum(numerator, na.rm = TRUE),
    .groups = "drop"
  ) %>%
  extract(
    measure,
    into  = c("Setting", "condition"),
    regex = "^(gp|pf)_consultation_(.*)$"
  ) %>%
  mutate(
    Setting = case_when(
      Setting == "gp" ~ "GP",
      Setting == "pf" ~ "PF"
    ),
    condition = case_when(
      condition == "uti"            ~ "UTI",
      condition == "sinusitis"      ~ "Sinusitis",
      condition == "insectbite"     ~ "Insect bites",
      condition == "otitismedia"    ~ "Otitis media",
      condition == "sorethroat"     ~ "Sore throat",
      condition == "shingles"       ~ "Shingles",
      condition == "impetigo"       ~ "Impetigo",
      condition == "all_conditions" ~ "All PF conditions"
    )
  )

# -----------------------------------------------------------------------------
# 3. Faceted plot
# -----------------------------------------------------------------------------
facet_numerators_plot <- ggplot(
  numerators_monthly,
  aes(
    x = interval_start,
    y = consultation_count,
    group = Setting,
    color = Setting,
    shape = Setting
  )
) +
  geom_line(linewidth = 0.5) +
  geom_point(size = 2.5, color = "red") +
  geom_vline(xintercept = GP_connect, linetype = "dashed", linewidth = 0.3) +
  geom_vline(xintercept = PF_start, linetype = "dashed", linewidth = 0.3,color = "blue") +
  facet_wrap(
    ~ condition,
    scales = "free_y",
    ncol = 2
  ) +
  scale_x_date(
    date_labels = "%Y-%m",
    date_breaks = "2 months"
  ) +
  labs(
    title = "Monthly consultation counts by condition and setting",
    x = "Month",
    y = "Consultation count"
  ) +
  theme_bw() +
  theme(
    legend.position = "bottom",
    axis.text.x = element_text(angle = 45, hjust = 1),
    strip.text = element_text(face = "bold")
  )

facet_numerators_plot

# -----------------------------------------------------------------------------
# 4. Save as PNG
# -----------------------------------------------------------------------------
ggsave(
  filename = here("output", "measures_new_approach_facet_consultation.png"),
  plot = facet_numerators_plot,
  width = 10,
  height = 6,
  dpi = 300
)





#.......................................................................................



library(tidyverse)
library(lubridate)
library(scales)
library(here)

# 1. Import data

practice_level_data_by_practice_only <- read_csv(
  here("output", "practice_level_data_by_practice_only.csv"),
  show_col_types = FALSE
) %>%
  mutate(
    interval_start = as.Date(interval_start)
  )

# 2. Practice-level proportions 

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
    month,
    starts_with("gp_proportion_"),
    starts_with("pf_proportion_")
  )

# 3. Convert to long format

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
      gp = "General Practice",
      pf = "Pharmacy First"
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

# 4. Calculate monthly mean and 95% confidence intervals

monthly_summary <- data_long %>%
  filter(
    !is.na(proportion),
    is.finite(proportion)
  ) %>%
  group_by(
    interval_start,
    month,
    setting,
    condition
  ) %>%
  summarise(
    n_practices = n(),
    mean_proportion = mean(proportion),
    sd_proportion = sd(proportion),
    se = sd_proportion / sqrt(n_practices),
    lower_ci = mean_proportion - 1.96 * se,
    upper_ci = mean_proportion + 1.96 * se,
    .groups = "drop"
  ) %>%
  mutate(
    lower_ci = pmax(0, lower_ci),
    upper_ci = pmin(100, upper_ci)
  )

# 5. Define graph colours

setting_colours <- c(
  "General Practice" = "#0072B2",
  "Pharmacy First" = "#D55E00"
)

# 6. Define plotting function

plot_condition <- function(condition_name) {

  plot_data <- monthly_summary %>%
    filter(condition == condition_name)

  ggplot(
    plot_data,
    aes(
      x = interval_start,
      y = mean_proportion,
      colour = setting,
      fill = setting,
      group = setting
    )
  ) +

    geom_ribbon(
      aes(
        ymin = lower_ci,
        ymax = upper_ci
      ),
      alpha = 0.15,
      colour = NA
    ) +

    geom_line(
      linewidth = 0.9
    ) +

    geom_vline(
      xintercept = as.Date("2024-02-01"),
      linetype = "dashed",
      colour = "black",
      linewidth = 0.6
    ) +

    geom_vline(
      xintercept = as.Date("2025-10-01"),
      linetype = "dashed",
      colour = "grey40",
      linewidth = 0.6
    ) +

    scale_x_date(
      date_breaks = "3 months",
      date_labels = "%b\n%Y"
    ) +

    scale_y_continuous(
      limits = c(0, 100),
      breaks = seq(0, 100, 10),
      labels = label_number(suffix = "%")
    ) +

    scale_colour_manual(
      values = setting_colours
    ) +

    scale_fill_manual(
      values = setting_colours
    ) +

    labs(
      title = condition_name,
      subtitle = "Monthly mean proportion across practices",
      x = NULL,
      y = "Consultations resulting in medication (%)",
      colour = NULL,
      fill = NULL,
      caption = paste(
        "Black dashed line: Pharmacy First launch (February 2024).",
        "Grey dashed line: GP Connect (October 2025).",
        "Shaded areas: 95% confidence intervals."
      )
    ) +

    theme_minimal(base_size = 12) +

    theme(
      legend.position = "bottom",
      plot.title = element_text(
        face = "bold",
        size = 14
      ),
      plot.subtitle = element_text(size = 10),
      axis.text.x = element_text(size = 9),
      panel.grid.minor = element_blank(),
      panel.grid.major.x = element_blank(),
      plot.caption = element_text(
        size = 8,
        hjust = 0
      )
    )
}

# 7. Generate individual graphs

condition_order <- c(
  "UTI",
  "Sinusitis",
  "Insect bites",
  "Otitis media",
  "Sore throat",
  "Shingles",
  "Impetigo",
  "All conditions"
)

plots <- set_names(
  map(condition_order, plot_condition),
  condition_order
)

# Display individual graphs

plots[["UTI"]]
plots[["Sinusitis"]]
plots[["Insect bites"]]
plots[["Otitis media"]]
plots[["Sore throat"]]
plots[["Shingles"]]
plots[["Impetigo"]]
plots[["All conditions"]]

# 8. Save individual graphs

output_dir <- here(
  "output",
  "practice_proportion_graphs"
)

dir.create(
  output_dir,
  recursive = TRUE,
  showWarnings = FALSE
)

walk2(
  plots,
  names(plots),
  ~ ggsave(
    filename = file.path(
      output_dir,
      paste0(
        str_replace_all(
          tolower(.y),
          " ",
          "_"
        ),
        ".png"
      )
    ),
    plot = .x,
    width = 11,
    height = 6,
    dpi = 300
  )
)

# 9. Combined eight-panel graph

combined_plot <- ggplot(
  monthly_summary,
  aes(
    x = interval_start,
    y = mean_proportion,
    colour = setting,
    fill = setting,
    group = setting
  )
) +

  geom_ribbon(
    aes(
      ymin = lower_ci,
      ymax = upper_ci
    ),
    alpha = 0.12,
    colour = NA
  ) +

  geom_line(
    linewidth = 0.65
  ) +

  geom_vline(
    xintercept = as.Date("2024-02-01"),
    linetype = "dashed",
    colour = "black",
    linewidth = 0.45
  ) +

  geom_vline(
    xintercept = as.Date("2025-10-01"),
    linetype = "dashed",
    colour = "grey40",
    linewidth = 0.45
  ) +

  facet_wrap(
    ~ condition,
    ncol = 2,
    scales = "fixed"
  ) +

  scale_x_date(
    date_breaks = "6 months",
    date_labels = "%b\n%Y"
  ) +

  scale_y_continuous(
    limits = c(0, 100),
    breaks = seq(0, 100, 20),
    labels = label_number(suffix = "%")
  ) +

  scale_colour_manual(
    values = setting_colours
  ) +

  scale_fill_manual(
    values = setting_colours
  ) +

  labs(
    title = "Practice-level antimicrobial prescribing",
    subtitle = "Monthly mean proportion of consultations resulting in medication",
    x = NULL,
    y = "Consultations resulting in medication (%)",
    colour = NULL,
    fill = NULL,
    caption = paste(
      "Black dashed line: Pharmacy First launch (February 2024).",
      "Grey dashed line: GP Connect (October 2025).",
      "Shaded areas: 95% confidence intervals across practices."
    )
  ) +

  theme_minimal(base_size = 11) +

  theme(
    legend.position = "bottom",
    plot.title = element_text(
      face = "bold",
      size = 15
    ),
    strip.text = element_text(
      face = "bold",
      size = 11
    ),
    panel.grid.minor = element_blank(),
    panel.grid.major.x = element_blank(),
    plot.caption = element_text(
      size = 8,
      hjust = 0
    )
  )

# Display combined graph

combined_plot

# Save combined graph

ggsave(
  filename = file.path(
    output_dir,
    "all_conditions_combined.png"
  ),
  plot = combined_plot,
  width = 14,
  height = 18,
  dpi = 300
)

# 10. Save the small practice-level dataset

write_csv(
  data,
  file.path(
    output_dir,
    "practice_level_proportions.csv"
  )
)

# Save monthly summaries

write_csv(
  monthly_summary,
  file.path(
    output_dir,
    "monthly_mean_proportions.csv"
  )
)


