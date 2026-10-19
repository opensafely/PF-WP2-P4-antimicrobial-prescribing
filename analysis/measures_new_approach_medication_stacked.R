

# Monthly and annual medication counts by condition and setting

library(tidyverse)
library(here)
library(scales)
library(lubridate)
library(readr)

# 1. Data

measures_new_approach <- read_csv(
  here("output", "measures_new_approach_medication.csv"),
  show_col_types = FALSE
) %>%
  mutate(
    interval_start = as.Date(interval_start)
  )

# Key intervention dates
GP_connect <- as.Date("2025-10-01")
PF_start   <- as.Date("2024-02-01")

message("Number of rows: ", nrow(measures_new_approach))
message("Number of columns: ", ncol(measures_new_approach))
message(
  "Date range: ",
  min(measures_new_approach$interval_start, na.rm = TRUE),
  " to ",
  max(measures_new_approach$interval_start, na.rm = TRUE)
)

#print(head(measures_new_approach))
# Check output directory
#if (!dir.exists(here("output"))) {
#  stop("The output directory does not exist: ", here("output"))
#}

# Conditions
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

# Expected measure naming convention
measure_pattern <- paste0(
  "^(gp|pf)_medication_(",
  paste(conditions, collapse = "|"),
  ")$"
)

# Shared plotting theme
theme_pf <- theme_bw() +
  theme(
    legend.position = "bottom",
    axis.text.x = element_text(angle = 45, hjust = 1),
    strip.text = element_text(face = "bold"),
    plot.title = element_text(face = "bold"),
    panel.grid.minor = element_blank()
  )

# -----------------------------------------------------------------------------
# 2.a. Monthly medication counts by condition and setting
# -----------------------------------------------------------------------------

numerators_monthly <- measures_new_approach %>%
  filter(
    str_detect(measure, measure_pattern)
  ) %>%
  group_by(interval_start, measure) %>%
  summarise(
    medication_count = sum(numerator, na.rm = TRUE),
    .groups = "drop"
  ) %>%
  extract(
    measure,
    into = c("Setting", "condition"),
    regex = "^(gp|pf)_medication_(.*)$"
  ) %>%
  mutate(
    Setting = recode(
      Setting,
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
      all_conditions = "All PF conditions"
    )
  )

# Inspect monthly data
print(numerators_monthly)

# -----------------------------------------------------------------------------
# 2.b. Monthly stacked barplot: condition-specific medication counts
# -----------------------------------------------------------------------------

# Exclude the all-conditions aggregate to avoid double-counting
stacked_data <- numerators_monthly %>%
  filter(condition != "All PF conditions") %>%
  mutate(
    condition = fct_reorder(
      condition,
      medication_count,
      .fun = sum,
      .desc = TRUE
    )
  )

stacked_plot <- ggplot(
  stacked_data,
  aes( x = interval_start, y = medication_count, fill = condition )) +
  geom_col( width = 23, position = "stack") +
  geom_vline(
    xintercept = PF_start,
    linetype = "dashed",
    linewidth = 0.5,
    colour = "blue"
  ) +
  geom_vline(
    xintercept = GP_connect,
    linetype = "dashed",
    linewidth = 0.5,
    colour = "black"
  ) +
  facet_wrap(~ Setting, ncol = 1, scales = "free_y") +
  scale_x_date(
    date_labels = "%Y-%m",
    date_breaks = "2 months",
    expand = expansion(mult = c(0.01, 0.03))
  ) +
  scale_y_continuous(
    labels = comma,
    expand = expansion(mult = c(0, 0.08))
  ) +
  scale_fill_brewer(
    palette = "Set2",
    name = "Condition"
  ) +
  guides(
    fill = guide_legend(
      nrow = 2,
      title.position = "top"
    )
  ) +
  labs(
    title = "Monthly medication volume by condition and setting",
    subtitle = paste(
      "Blue dashed line: Pharmacy First launch;",
      "black dashed line: GP Connect implementation"
    ),
    x = "Month",
    y = "Medication count"
  ) +
  theme_pf

print(stacked_plot)

ggsave(
  filename = here(
    "output",
    "measures_new_approach_medication_stacked.png"
  ),
  plot = stacked_plot,
  width = 11,
  height = 8,
  dpi = 300
)

# -----------------------------------------------------------------------------
# 3.a. Annual medication counts by condition and setting
# -----------------------------------------------------------------------------

numerators_annual <- numerators_monthly %>%
  mutate(
    year = year(interval_start)
  ) %>%
  group_by(year, Setting, condition) %>%
  summarise(
    medication_count = sum(medication_count, na.rm = TRUE),
    months_observed = n_distinct(month(interval_start)),
    .groups = "drop"
  )

# -----------------------------------------------------------------------------
# 3.b. Annual stacked barplot: GP vs PF
# -----------------------------------------------------------------------------

stacked_annual_data <- numerators_annual %>%
  filter(condition != "All PF conditions") %>%
  mutate(
    condition = fct_reorder(
      condition,
      medication_count,
      .fun = sum,
      .desc = TRUE
    )
  )

stacked_annual_plot <- ggplot(
  stacked_annual_data,
  aes(
    x = factor(year),
    y = medication_count,
    fill = condition
  )
) +
  geom_col(
    position = "stack",
    width = 0.7
  ) +
  facet_wrap(
    ~ Setting,
    ncol = 1,
    scales = "free_y"
  ) +
  scale_y_continuous(
    labels = comma,
    expand = expansion(mult = c(0, 0.08))
  ) +
  scale_fill_brewer(
    palette = "Set2",
    name = "Condition"
  ) +
  guides(
    fill = guide_legend(
      nrow = 2,
      title.position = "top"
    )
  ) +
  labs(
    title = "Annual medication volume by condition and setting",
    subtitle = "Totals summed across observed months; partial years may be incomplete",
    x = "Year",
    y = "Medication count"
  ) +
  theme_pf

print(stacked_annual_plot)

ggsave(
  filename = here(
    "output",
    "measures_new_approach_medication_stacked_annual.png"
  ),
  plot = stacked_annual_plot,
  width = 11,
  height = 8,
  dpi = 300
)

# -----------------------------------------------------------------------------
# 4. Annual medication counts and year-on-year changes
# -----------------------------------------------------------------------------

medication_annual <- numerators_monthly %>%
  mutate(
    year = year(interval_start),
    month = month(interval_start)
  ) %>%
  group_by(condition, Setting, year) %>%
  summarise(
    annual_count = sum(medication_count, na.rm = TRUE),
    months_observed = n_distinct(month),
    .groups = "drop"
  ) %>%
  arrange(condition, Setting, year) %>%
  group_by(condition, Setting) %>%
  mutate(
    previous_year = lag(year),
    previous_count = lag(annual_count),
    previous_months = lag(months_observed),

    # Consecutive calendar years
    consecutive_years = !is.na(previous_year) &
      year == previous_year + 1,

    # Full-year coverage indicator
    full_year = months_observed == 12,
    previous_full_year = previous_months == 12,

    # Absolute change for consecutive years
    absolute_change = if_else(
      consecutive_years,
      annual_count - previous_count,
      NA_real_
    ),

    # Percentage change only for consecutive, complete years
    percentage_change = if_else(
      consecutive_years &
        full_year &
        previous_full_year &
        !is.na(previous_count) &
        previous_count > 0,
      (annual_count - previous_count) /
        previous_count * 100,
      NA_real_
    ),

    # Labels for plots
    change_label = if_else(
      is.na(percentage_change),
      "",
      sprintf("(%+.1f%%)", percentage_change)
    ),

    bar_label = if_else(
      change_label == "",
      paste0(
        comma(annual_count),
        if_else(full_year, "", "*")
      ),
      paste0(
        comma(annual_count),
        "\n",
        change_label
      )
    )
  ) %>%
  ungroup()

# Inspect annual summary
print(medication_annual, n = Inf)

# Export annual summary table
#write_csv(medication_annual, here("output","measures_new_approach_annual_medication_counts_and_changes.csv"))

# ------------------------------------------------------------------------------------------------------------
# 5. Figure 1: Annual medication counts with percentage changes
# -------------------------------------------------------------------------------------------------------------

annual_counts_plot <- ggplot( medication_annual, aes(x = factor(year), y = annual_count,fill = Setting)) +
  geom_col( position = position_dodge(width = 0.85),width = 0.75) +
  geom_text(
    aes(label = bar_label),
    position = position_dodge(width = 0.85),
    vjust = -0.2,
    size = 2.6,
    lineheight = 0.95,
    show.legend = FALSE
  ) +
  facet_wrap(
    ~ condition,
    scales = "free_y",
    ncol = 2
  ) +
  scale_y_continuous(
    labels = comma,
    expand = expansion(mult = c(0, 0.30))
  ) +
  labs(
    title = "Annual medication counts by condition and setting",
    subtitle = paste(
      "Labels show annual totals and percentage changes",
      "from the previous consecutive, complete calendar year"
    ),
    caption = paste(
      "* Annual total based on fewer than 12 observed months.",
      "Percentage changes are omitted for incomplete years."
    ),
    x = "Year",
    y = "Annual medication count",
    fill = "Setting"
  ) +
  theme_pf

print(annual_counts_plot)

ggsave(
  filename = here(
    "output",
    "measures_new_approach_facet_medication_annual.png"
  ),
  plot = annual_counts_plot,
  width = 13,
  height = 10,
  dpi = 300
)


# -----------------------------------------------------------------------------
# 6. Figure 2: Year-on-year percentage change
# -----------------------------------------------------------------------------

medication_annual_change <- medication_annual %>%
  filter(!is.na(percentage_change)) %>%
  mutate(
    change_label = sprintf("%+.1f%%", percentage_change)
  )

message(
  "Number of valid year-on-year comparisons: ",
  nrow(medication_annual_change)
)

if (nrow(medication_annual_change) > 0) {

  annual_change_plot <- ggplot(
    medication_annual_change,
    aes(
      x = year,
      y = percentage_change,
      color = Setting,
      group = Setting
    )
  ) +
    geom_hline(
      yintercept = 0,
      linetype = "dashed",
      linewidth = 0.4,
      colour = "grey50"
    ) +
    geom_line(linewidth = 0.6) +
    geom_point(size = 2) +
    geom_text(
      aes(
        label = change_label,
        vjust = if_else(
          percentage_change >= 0, -0.8, 1.3
        )
      ),
      size = 2.7,
      show.legend = FALSE,
      check_overlap = TRUE
    ) +
    facet_wrap(
      ~ condition,
      scales = "free_y",
      ncol = 2
    ) +
    scale_x_continuous(
      breaks = sort(unique(medication_annual_change$year))
    ) +
    scale_y_continuous(
      labels = label_number(suffix = "%"),
      expand = expansion(mult = c(0.20, 0.30))
    ) +
    labs(
      title = "Year-on-year change in medication counts",
      subtitle = paste(
        "Consecutive complete calendar years only;",
        "previous-year count must be greater than zero"
      ),
      x = "Year",
      y = "Change from previous year (%)",
      color = "Setting"
    ) +
    theme_pf

} else {

  message(
    "No eligible year-on-year percentage changes were found. ",
    "Check annual counts, previous-year counts and year coverage."
  )

  annual_change_plot <- ggplot() +
    annotate(
      "text",
      x = 0,
      y = 0,
      label = paste(
        "No eligible year-on-year comparisons available.",
        "Check complete-year coverage and previous-year counts.",
        sep = "\n"
      ),
      size = 4
    ) +
    labs(
      title = "Year-on-year change in medication counts",
      x = NULL,
      y = NULL
    ) +
    theme_void() +
    theme(
      plot.title = element_text(
        face = "bold",
        hjust = 0.5
      )
    ) +
    xlim(-1, 1) +
    ylim(-1, 1)
}

print(annual_change_plot)

ggsave(
  filename = here(
    "output",
    "measures_new_approach_facet_medication_annual_percentage_change.png"
  ),
  plot = annual_change_plot,
  width = 13,
  height = 10,
  dpi = 300
)

# -----------------------------------------------------------------------------
# 7. Data quality checks
# -----------------------------------------------------------------------------

# Check monthly coverage by setting, condition and year
monthly_coverage <- numerators_monthly %>%
  mutate(
    year = year(interval_start),
    month = month(interval_start)
  ) %>%
  group_by(Setting, condition, year) %>%
  summarise(
    months_observed = n_distinct(month),
    total_count = sum(medication_count, na.rm = TRUE),
    .groups = "drop"
  ) %>%
  arrange(Setting, condition, year)

print(monthly_coverage, n = Inf)

# Identify years with fewer than 12 observed months
incomplete_years <- medication_annual %>%
  filter(months_observed < 12) %>%
  select(
    condition,
    Setting,
    year,
    months_observed,
    annual_count
  )

message("Annual summaries with fewer than 12 observed months:")
print(incomplete_years, n = Inf)

# Check that the stacked plots exclude the aggregate condition
stopifnot(
  !any(stacked_data$condition == "All PF conditions"),
  !any(stacked_annual_data$condition == "All PF conditions")
)

#message("All plots and the annual summary table have been saved.")
