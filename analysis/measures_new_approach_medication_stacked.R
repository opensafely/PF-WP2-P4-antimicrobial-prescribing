
# This code shows monthly and annual medication counts by condition and setting
# Statistical disclosure control follows OpenSAFELY guidelines:
#   1. Counts <= 7 are redacted (shown as "[REDACTED]" in CSVs).
#   2. All remaining counts are rounded to the nearest 5.
#   3. Annual totals are computed from raw monthly data, then protected.
#   4. Changes (absolute and %) are derived ONLY from protected counts, and
#      are NA whenever either count is redacted, so no released value can be
#      used to back-calculate a redacted one.
#   5. Every figure is drawn from protected values, not raw counts.

library(tidyverse)
library(here)
library(scales)
library(lubridate)
# -----------------------------------------------------------------------------
# 0. SDC 
# -----------------------------------------------------------------------------
sdc_threshold <- 7
sdc_base <- 5
# Numeric protected count: NA if redacted (1-7), zero kept as zero,
# Everything else rounded to the nearest 5. Integer counts never fall on a .5
# tie when divided by 5, so round() is unambiguous here.
sdc_count <- function(x, threshold = sdc_threshold, base = sdc_base) {
  case_when(
    is.na(x) ~ NA_real_,
    x == 0 ~ 0,
    x <= threshold ~ NA_real_,
    TRUE ~ round(x / base) * base
  )
}
# Flag for counts that were redacted
sdc_redacted <- function(x, threshold = sdc_threshold) {
  !is.na(x) & x > 0 & x <= threshold
}

# Version for release: "[REDACTED]" or the rounded count
sdc_label <- function(x) {
  if_else(sdc_redacted(x), "[REDACTED]", as.character(sdc_count(x)))
}

sdc_caption <- paste0(
  "Counts \u2264", sdc_threshold, " redacted; all other counts rounded to the nearest ",
  sdc_base, "."
)

# -----------------------------------------------------------------------------
# 1. Data
# -----------------------------------------------------------------------------

measures_new_approach <- read_csv(
  here("output", "measures_new_approach_medication.csv"),
  show_col_types = FALSE
) %>%
  mutate(interval_start = as.Date(interval_start))

# Key intervention dates
GP_connect <- as.Date("2025-10-01")
PF_start   <- as.Date("2024-02-01")

# For information only (no counts) goes to the log
message("Number of rows: ", nrow(measures_new_approach))
message("Number of columns: ", ncol(measures_new_approach))
message(
  "Date range: ",
  min(measures_new_approach$interval_start, na.rm = TRUE), " to ",
  max(measures_new_approach$interval_start, na.rm = TRUE)
)

conditions <- c(
  "uti", "sinusitis", "insectbite", "otitismedia",
  "sorethroat", "shingles", "impetigo", "all_conditions"
)

measure_pattern <- paste0(
  "^(gp|pf)_medication_(", paste(conditions, collapse = "|"), ")$"
)

theme_pf <- theme_bw() +
  theme(
    legend.position = "bottom",
    axis.text.x = element_text(angle = 45, hjust = 1),
    strip.text = element_text(face = "bold"),
    plot.title = element_text(face = "bold"),
    panel.grid.minor = element_blank()
  )

# -----------------------------------------------------------------------------
# 2. Monthly counts (raw, then protected)
# -----------------------------------------------------------------------------

numerators_monthly <- measures_new_approach %>%
  filter(str_detect(measure, measure_pattern)) %>%
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
    Setting = recode(Setting, gp = "GP", pf = "PF"),
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

# Exclude the all-conditions aggregate from stacked plots (double-counting)
stacked_data <- numerators_monthly %>%
  filter(condition != "All PF conditions") %>%
  mutate(
    medication_count_sdc = sdc_count(medication_count),
    condition = fct_reorder(
      condition,
      medication_count_sdc,
      .fun = function(x) sum(x, na.rm = TRUE),
      .desc = TRUE
    )
  )

stacked_plot <- ggplot(
  stacked_data,
  aes(x = interval_start, y = medication_count_sdc, fill = condition)
) +
  geom_col(width = 23, position = "stack", na.rm = TRUE) +
  geom_vline(xintercept = PF_start, linetype = "dashed",
             linewidth = 0.5, colour = "blue") +
  geom_vline(xintercept = GP_connect, linetype = "dashed",
             linewidth = 0.5, colour = "black") +
  facet_wrap(~ Setting, ncol = 1, scales = "free_y") +
  scale_x_date(
    date_labels = "%Y-%m",
    date_breaks = "2 months",
    expand = expansion(mult = c(0.01, 0.03))
  ) +
  scale_y_continuous(labels = comma, expand = expansion(mult = c(0, 0.08))) +
  scale_fill_brewer(palette = "Set2", name = "Condition") +
  guides(fill = guide_legend(nrow = 1, title.position = "top")) +
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

ggsave(
  here("output", "measures_new_approach_medication_stacked.png"),
  plot = stacked_plot, width = 11, height = 8, dpi = 300
)

# Underlying data for the monthly figure (protected values only)
write_csv(
  stacked_data %>%
    arrange(Setting, interval_start, condition) %>%
    transmute(
      interval_start,
      Setting,
      condition,
      medication_count = sdc_label(medication_count)
    ),
  here("output", "measures_new_approach_medication_stacked.csv")
)

# -----------------------------------------------------------------------------
# 3. Annual summaries (calendar and February-January reporting years)
# -----------------------------------------------------------------------------

summarise_annual <- function(monthly, year_type = c("calendar", "reporting")) {
  year_type <- match.arg(year_type)

  monthly %>%
    mutate(
      calendar_year = year(interval_start),
      month = month(interval_start),
      year = if (year_type == "calendar") {
        calendar_year
      } else {
        if_else(month >= 2, calendar_year, calendar_year - 1)
      },
      period = if (year_type == "calendar") {
        as.character(year)
      } else {
        paste0("Feb ", year, "\u2013Jan ", year + 1)
      }
    ) %>%
    group_by(condition, Setting, year, period) %>%
    summarise(
      annual_count_raw = sum(medication_count, na.rm = TRUE),
      months_observed = n_distinct(interval_start),
      .groups = "drop"
    ) %>%
    mutate(
      annual_count = sdc_count(annual_count_raw),
      redacted = sdc_redacted(annual_count_raw)
    ) %>%
    select(-annual_count_raw) %>%   # raw totals never leave this function
    arrange(condition, Setting, year) %>%
    group_by(condition, Setting) %>%
    mutate(
      previous_year = lag(year),
      previous_count = lag(annual_count),
      previous_redacted = coalesce(lag(redacted), FALSE),
      previous_months = lag(months_observed),

      consecutive_years = !is.na(previous_year) & year == previous_year + 1,
      full_year = months_observed == 12,
      previous_full_year = !is.na(previous_months) & previous_months == 12,

      # Both changes use protected counts and are NA if either is redacted
      absolute_change = if_else(
        consecutive_years & !is.na(annual_count) & !is.na(previous_count),
        annual_count - previous_count,
        NA_real_
      ),
      percentage_change = if_else(
        consecutive_years & full_year & previous_full_year &
          !is.na(annual_count) & !is.na(previous_count) & previous_count > 0,
        (annual_count - previous_count) / previous_count * 100,
        NA_real_
      ),

      change_label = if_else(
        is.na(percentage_change), "",
        sprintf("(%+.1f%%)", percentage_change)
      ),
      count_label = if_else(redacted, "[REDACTED]", comma(annual_count)),
      bar_label = if_else(
        change_label != "",
        paste0(count_label, "\n", change_label),
        paste0(count_label, if_else(full_year, "", "*"))
      ),
      period = fct_reorder(period, year)
    ) %>%
    ungroup()
}

# Release table: protected counts and derived changes only
release_annual <- function(df, file) {
  write_csv(
    df %>%
      transmute(
        condition,
        Setting,
        year,
        period,
        months_observed,
        annual_count = if_else(
          redacted, "[REDACTED]", as.character(annual_count)
        ),
        previous_count = if_else(
          previous_redacted, "[REDACTED]", as.character(previous_count)
        ),
        absolute_change,
        percentage_change
      ),
    here("output", file)
  )
}

medication_calendar  <- summarise_annual(numerators_monthly, "calendar")
medication_reporting <- summarise_annual(numerators_monthly, "reporting")

# -----------------------------------------------------------------------------
# 3.a. Annual stacked barplot (calendar years)
# -----------------------------------------------------------------------------

stacked_annual_data <- medication_calendar %>%
  filter(condition != "All PF conditions") %>%
  mutate(
    condition = fct_reorder(
      condition, annual_count,
      .fun = function(x) sum(x, na.rm = TRUE),
      .desc = TRUE
    )
  )

stacked_annual_plot <- ggplot(
  stacked_annual_data,
  aes(x = period, y = annual_count, fill = condition)
) +
  geom_col(position = "stack", width = 0.7, na.rm = TRUE) +
  facet_wrap(~ Setting, ncol = 1, scales = "free_y") +
  scale_y_continuous(labels = comma, expand = expansion(mult = c(0, 0.08))) +
  scale_fill_brewer(palette = "Set2", name = "Condition") +
  guides(fill = guide_legend(nrow = 1, title.position = "top")) +
  labs(
    title = "Annual medication volume by condition and setting",
    subtitle = "Totals summed across observed months; partial years may be incomplete",
    x = "Year",
    y = "Medication count"
  ) +
  theme_pf

ggsave(
  here("output", "measures_new_approach_medication_stacked_annual.png"),
  plot = stacked_annual_plot, width = 11, height = 8, dpi = 300
)

release_annual(
  stacked_annual_data %>% arrange(Setting, year, condition),
  "measures_new_approach_medication_stacked_annual.csv"
)

# -----------------------------------------------------------------------------
# 4. Annual counts with % change: shared plotting function
# -----------------------------------------------------------------------------

plot_annual_counts <- function(df, subtitle, caption, x_lab) {
  ggplot(df, aes(x = period, y = annual_count, fill = Setting)) +
    geom_col(position = position_dodge(width = 0.85), width = 0.75, na.rm = TRUE) +
    geom_text(
      # Redacted bars have no height; place their label at zero
      aes(y = coalesce(annual_count, 0), label = bar_label),
      position = position_dodge(width = 0.85),
      vjust = -0.2,
      size = 2.6,
      lineheight = 0.95,
      show.legend = FALSE
    ) +
    facet_wrap(~ condition, scales = "free_y", ncol = 2) +
    scale_x_discrete(drop = FALSE) +
    scale_y_continuous(labels = comma, expand = expansion(mult = c(0, 0.30))) +
    labs(
      title = "Annual medication counts by condition and setting",
      subtitle = subtitle,
      caption = caption,
      x = x_lab,
      y = "Annual medication count",
      fill = "Setting"
    ) +
    theme_pf
}

# 4.a. Figure 1: calendar years
annual_counts_plot <- plot_annual_counts(
  medication_calendar,
  subtitle = paste(
    "Labels show annual totals and percentage changes",
    "from the previous consecutive, complete calendar year"
  ),
  caption = paste(
    "* Annual total based on fewer than 12 observed months.",
    "Percentage changes are omitted for incomplete years."
  ),
  x_lab = "Year"
)

ggsave(
  here("output", "measures_new_approach_facet_medication_annual.png"),
  plot = annual_counts_plot, width = 13, height = 10, dpi = 300
)

release_annual(
  medication_calendar,
  "measures_new_approach_facet_medication_annual.csv"
)

# 4.b. Figure 2: February-January reporting years
full_annual_counts_plot <- plot_annual_counts(
  medication_reporting,
  subtitle = paste(
    "February\u2013January reporting years;",
    "labels show annual totals and year-on-year percentage changes"
  ),
  caption = paste(
    "* Reporting period based on fewer than 12 observed months.",
    "Percentage changes are omitted when either reporting year",
    "is incomplete or the previous count is zero."
  ),
  x_lab = "Reporting year (February\u2013January)"
)

ggsave(
  here("output", "measures_new_approach_facet_medication_full_annual.png"),
  plot = full_annual_counts_plot, width = 13, height = 10, dpi = 300
)

release_annual(
  medication_reporting,
  "measures_new_approach_facet_medication_full_annual.csv"
)

# -----------------------------------------------------------------------------
# 5. Figure 3: Year-on-year percentage change
# Uses calendar years, matching the original figure labels.
# -----------------------------------------------------------------------------

change_source <- medication_calendar
change_x_lab  <- "Year"

medication_annual_change <- change_source %>%
  filter(!is.na(percentage_change)) %>%
  mutate(change_label = sprintf("%+.1f%%", percentage_change))

message(
  "Number of valid year-on-year comparisons: ",
  nrow(medication_annual_change)
)

if (nrow(medication_annual_change) > 0) {

  annual_change_plot <- ggplot(
    medication_annual_change,
    aes(x = period, y = percentage_change, colour = Setting, group = Setting)
  ) +
    geom_hline(yintercept = 0, linetype = "dashed",
               linewidth = 0.4, colour = "grey50") +
    geom_line(linewidth = 0.6) +
    geom_point(size = 2) +
    geom_text(
      aes(
        label = change_label,
        vjust = if_else(percentage_change >= 0, -0.8, 1.3)
      ),
      size = 2.7,
      show.legend = FALSE,
      check_overlap = TRUE
    ) +
    facet_wrap(~ condition, scales = "free_y", ncol = 2) +
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
      x = change_x_lab,
      y = "Change from previous year (%)",
      colour = "Setting"
    ) +
    theme_pf

} else {

  annual_change_plot <- ggplot() +
    annotate(
      "text", x = 0, y = 0, size = 4,
      label = paste(
        "No eligible year-on-year comparisons available.",
        "Check complete-year coverage and previous-year counts.",
        sep = "\n"
      )
    ) +
    labs(title = "Year-on-year change in medication counts", x = NULL, y = NULL) +
    theme_void() +
    theme(plot.title = element_text(face = "bold", hjust = 0.5)) +
    xlim(-1, 1) +
    ylim(-1, 1)
}

ggsave(
  here("output", "measures_new_approach_facet_medication_annual_percentage_change.png"),
  plot = annual_change_plot, width = 13, height = 10, dpi = 300
)

release_annual(
  medication_annual_change,
  "measures_new_approach_facet_medication_annual_percentage_change.csv"
)

# -----------------------------------------------------------------------------
# 6. Data quality checks (no patient counts written to the log)
# -----------------------------------------------------------------------------

# Coverage only: months observed per setting/condition/calendar year
monthly_coverage <- numerators_monthly %>%
  mutate(year = year(interval_start)) %>%
  group_by(Setting, condition, year) %>%
  summarise(months_observed = n_distinct(interval_start), .groups = "drop") %>%
  arrange(Setting, condition, year)

print(monthly_coverage, n = Inf)

message("Reporting years with fewer than 12 observed months:")
print(
  medication_reporting %>%
    filter(months_observed < 12) %>%
    select(condition, Setting, period, months_observed),
  n = Inf
)

stopifnot(
  !any(stacked_data$condition == "All PF conditions"),
  !any(stacked_annual_data$condition == "All PF conditions"),
  # every protected count is a multiple of the rounding base
  all(stacked_data$medication_count_sdc %% sdc_base == 0, na.rm = TRUE),
  all(medication_calendar$annual_count %% sdc_base == 0, na.rm = TRUE),
  all(medication_reporting$annual_count %% sdc_base == 0, na.rm = TRUE)
)

message("All figures and SDC-protected tables have been saved.")