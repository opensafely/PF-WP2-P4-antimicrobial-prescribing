# Practice-level distribution plots (A, D1, D2, F) by setting, measure, condition
#
# Statistical disclosure control (OpenSAFELY guidance):
#   1. Every count is summed from RAW data first (practice-month, practice-year,
#      national month), and only then protected: counts <= 7 redacted (NA),
#      all other counts rounded to the nearest 5. Zeros are kept.
#   2. All plotted values (Y, baselines, changes, national mean, F changes)
#      are derived ONLY from protected counts. Raw columns (num, den) are used
#      solely as inputs to sdc_count() and never plotted or written out.
#   3. Because every series (GP, PF, GP + PF, each condition, all_conditions)
#      is rounded independently, differencing series (e.g. GP+PF minus GP)
#      only recovers a range, not a redacted value.
#   4. Underlying data for every figure is written next to it, using
#      [REDACTED] and an anonymous rank instead of the practice ID.
# SDC is applied in: sdc_count(), period_value(), make_panel_plots().

library(tidyverse)
library(lubridate)
library(here)
library(scales)

# -----------------------------------------------------------------------------
# 0. SDC helpers
# -----------------------------------------------------------------------------

sdc_threshold <- 7
sdc_base <- 5

sdc_count <- function(x, threshold = sdc_threshold, base = sdc_base) {
  case_when(
    is.na(x) ~ NA_real_,
    x == 0 ~ 0,
    x <= threshold ~ NA_real_,
    TRUE ~ round(x / base) * base
  )
}

sdc_redacted <- function(x, threshold = sdc_threshold) {
  !is.na(x) & x > 0 & x <= threshold
}

# -----------------------------------------------------------------------------
# 1. Data
# -----------------------------------------------------------------------------

measures_new_approach_consultation_and_medication <- read_csv(
  "output/measures_new_approach_consultation_and_medication.csv",
  show_col_types = FALSE
)

# Structure only (row counts per measure, not patient counts)
names(measures_new_approach_consultation_and_medication)
table(measures_new_approach_consultation_and_medication$measure)

measures_consultation_medication <- measures_new_approach_consultation_and_medication %>%
  filter(grepl("consultation|medication", measure)) %>%
  mutate(
    setting = if_else(str_starts(measure, "gp_"), "GP", "PF"),
    measures = case_when(
      str_detect(measure, "_consultation_") ~ "consultations",
      str_detect(measure, "_medication_") ~ "medications"
    ),
    condition = measure %>%
      str_remove("^(gp|pf)_") %>%
      str_remove("^(consultation|medication)_")
  )

table(measures_consultation_medication$setting)
table(measures_consultation_medication$condition)
table(measures_consultation_medication$measures)

input_data <- measures_consultation_medication

# -----------------------------------------------------------------------------
# Settings
# -----------------------------------------------------------------------------

conditions <- c(
  "impetigo", "insectbite", "otitismedia", "shingles",
  "sinusitis", "sorethroat", "uti"
)

condition_labels <- c(
  impetigo = "Impetigo",
  insectbite = "Insect bites",
  otitismedia = "Otitis media",
  shingles = "Shingles",
  sinusitis = "Sinusitis",
  sorethroat = "Sore throat",
  uti = "UTI",
  all_conditions = "Total"
)

settings <- list(
  GP_PF = c("GP", "PF"),
  GP    = "GP",
  PF    = "PF"
)
setting_labels <- c(GP_PF = "GP + PF", GP = "GP only", PF = "PF only")

measures <- c("consultations", "medications")
measure_labels <- c(consultations = "Consultations", medications = "Medications")

use_rate    <- FALSE   # TRUE = per 1,000 registered patients (needs denominator)
out_dir     <- "output/distribution"
heatmap_dpi <- 600

# -----------------------------------------------------------------------------
# 1. Helpers
# -----------------------------------------------------------------------------

safe_mean <- function(x) if (all(is.na(x))) NA_real_ else mean(x, na.rm = TRUE)
safe_sum  <- function(x) if (all(is.na(x))) NA_real_ else sum(x, na.rm = TRUE)

# Protected value from protected numerator/denominator
to_value <- function(num_sdc, den_sdc) {
  if (use_rate) {
    if_else(!is.na(den_sdc) & den_sdc > 0, 1000 * num_sdc / den_sdc, NA_real_)
  } else {
    num_sdc
  }
}

# Protected period value (e.g. Year 1 baseline, Year 3/4 means):
# sum RAW counts over the period, protect the total, then convert to a
# monthly mean (counts) or a rate over the period (rates).
period_value <- function(num, den) {
  n_obs <- sum(!is.na(num))
  if (n_obs == 0) return(NA_real_)
  num_sdc <- sdc_count(sum(num, na.rm = TRUE))
  if (use_rate) {
    den_sdc <- sdc_count(sum(den, na.rm = TRUE))
    if (is.na(den_sdc) || den_sdc == 0) NA_real_ else 1000 * num_sdc / den_sdc
  } else {
    num_sdc / n_obs
  }
}

colour_limit <- function(x) {
  z <- as.numeric(quantile(abs(x), 0.99, na.rm = TRUE))
  if (!is.finite(z) || z <= 0) 1 else z
}

heat_theme <- theme_minimal(base_size = 12) +
  theme(
    panel.grid   = element_blank(),
    axis.text.y  = element_blank(),
    axis.ticks.y = element_blank()
  )

# -----------------------------------------------------------------------------
# 2. All series (setting version x measure x condition) - RAW sums
# -----------------------------------------------------------------------------

start_month <- min(as.Date(input_data$month), na.rm = TRUE)

base <- input_data %>%
  mutate(
    practice = as.character(practice),
    month_date = as.Date(month),
    month = (
      (year(month_date) - year(start_month)) * 12L +
        month(month_date) - month(start_month) + 1L
    ),
    numerator = as.numeric(numerator),
    denominator = as.numeric(denominator),
    condition = as.character(condition)
  ) %>%
  filter(
    !is.na(practice),
    month %in% 1:48,
    condition %in% conditions
  )

cat("Rows in base:", nrow(base), "\n")
cat("Number of practices:", n_distinct(base$practice), "\n")
cat("Months available:", paste(sort(unique(base$month)), collapse = ", "), "\n")

# Raw numerators are aggregated here; SDC is applied inside make_panel_plots()
# AFTER aggregation, so all_conditions and GP+PF are protected as totals.
build_series <- function(version) {

  by_cond <- base %>%
    filter(setting %in% settings[[version]]) %>%
    group_by(practice, month, measures, condition) %>%
    summarise(
      num = safe_sum(numerator),
      denominator = first(denominator),
      .groups = "drop"
    )

  all_conditions <- by_cond %>%
    group_by(practice, month, measures) %>%
    summarise(
      num = safe_sum(num),
      denominator = first(denominator),
      .groups = "drop"
    ) %>%
    mutate(condition = "all_conditions")

  bind_rows(by_cond, all_conditions) %>%
    mutate(version = version)
}

series <- map_dfr(names(settings), build_series)

print(dim(series))
print(table(series$version, series$measures))
print(table(series$condition))

# -----------------------------------------------------------------------------
# 3. Four graphs for one series (SDC applied here)
# -----------------------------------------------------------------------------

make_panel_plots <- function(dat, label, y_lab) {

  df <- dat %>%
    transmute(gp_id = practice, month, num, den = denominator)

  stopifnot(!anyDuplicated(df[c("gp_id", "month")]))

  # Complete panel so lag(Y, 12) is always 12 calendar months earlier
  df <- df %>%
    complete(gp_id, month = 1:48) %>%
    arrange(gp_id, month) %>%
    mutate(
      redacted = sdc_redacted(num),
      Y = to_value(sdc_count(num), sdc_count(den))      # protected value
    ) %>%
    group_by(gp_id) %>%
    mutate(
      baseline        = period_value(num[month <= 12], den[month <= 12]),
      change_baseline = Y - baseline,
      change_yoy      = Y - lag(Y, 12)
    ) %>%
    ungroup()

  # ---- A. Spaghetti ----
  # National mean = protected national total / number of practices reporting
  national <- df %>%
    group_by(month) %>%
    summarise(
      n_gp   = sum(!is.na(num)),
      mean_Y = if (use_rate) safe_mean(Y) else sdc_count(safe_sum(num)) / n_gp,
      .groups = "drop"
    )

  p_A <- ggplot(df, aes(month, Y, group = gp_id)) +
    geom_line(colour = "grey35", alpha = 0.035, linewidth = 0.18, na.rm = TRUE) +
    geom_line(data = national, aes(month, mean_Y), inherit.aes = FALSE,
      colour = "#B2182B", linewidth = 1.3, na.rm = TRUE) +
    scale_x_continuous(breaks = seq(0, 48, 6)) +
    labs(title = paste("A. GP practice trajectories -", label),
      subtitle = "All practices; red line = national practice mean",
      x = "Month", y = y_lab) +
    theme_minimal(base_size = 13)

  # ---- Sort practices by mean YoY change in Year 4 ----
  gp_order <- df %>%
    filter(month %in% 37:48) %>%
    group_by(gp_id) %>%
    summarise(sort_change = safe_mean(change_yoy), .groups = "drop") %>%
    arrange(!is.na(sort_change), sort_change, gp_id) %>%
    mutate(gp_rank = row_number())

  df <- df %>% left_join(gp_order %>% select(gp_id, gp_rank), by = "gp_id")
  n_gp <- nrow(gp_order)

  # ---- D1. Heatmap: change vs Year 1 ----
  lim_D1 <- colour_limit(df$change_baseline)
  p_D1 <- ggplot(df, aes(month, gp_rank, fill = change_baseline)) +
    geom_raster() +
    scale_fill_gradient2(low = "#2166AC", mid = "white", high = "#B2182B",
      midpoint = 0, limits = c(-lim_D1, lim_D1),
      oob = squish, na.value = "grey85", name = "Change") +
    scale_x_continuous(breaks = seq(1, 48, 6)) +
    labs(title = paste("D1. Change relative to Year 1 -", label),
      subtitle = paste(n_gp, "GPs sorted by recent annual change"),
      x = "Month", y = "GP practices") +
    heat_theme

  # ---- D2. Heatmap: year-on-year change ----
  lim_D2 <- colour_limit(df$change_yoy)
  p_D2 <- ggplot(df %>% filter(month >= 13),
    aes(month, gp_rank, fill = change_yoy)) +
    geom_raster() +
    scale_fill_gradient2(low = "#2166AC", mid = "white", high = "#B2182B",
      midpoint = 0, limits = c(-lim_D2, lim_D2),
      oob = squish, na.value = "grey85", name = "YoY change") +
    scale_x_continuous(breaks = seq(13, 48, 5)) +
    labs(title = paste("D2. Year-on-year change -", label),
      subtitle = "Y(t) - Y(t-12); largest recent increases at top",
      x = "Month", y = "GP practices") +
    heat_theme

  # ---- F. Distribution of annual changes ----
  F_month <- df %>%
    filter(month %in% c(36, 48)) %>%
    select(gp_id, month, Y) %>%
    pivot_wider(names_from = month, values_from = Y, names_prefix = "m") %>%
    filter(!is.na(m36), !is.na(m48)) %>%
    transmute(gp_id, change = m48 - m36,
      comparison = "Month 48 minus Month 36")

  # Year means from protected annual totals (not from monthly values)
  F_year <- df %>%
    filter(month %in% 25:48) %>%
    mutate(period = if_else(month <= 36, "Y3", "Y4")) %>%
    group_by(gp_id, period) %>%
    summarise(
      n_obs  = sum(!is.na(num)),
      mean_Y = period_value(num, den),
      .groups = "drop"
    ) %>%
    filter(n_obs == 12) %>%
    select(-n_obs) %>%
    pivot_wider(names_from = period, values_from = mean_Y) %>%
    filter(!is.na(Y3), !is.na(Y4)) %>%
    transmute(gp_id, change = Y4 - Y3,
      comparison = "Mean Year 4 minus Mean Year 3")

  p_F <- ggplot(bind_rows(F_month, F_year), aes(change)) +
    geom_histogram(bins = 60, fill = "#4775A8", colour = "white") +
    geom_vline(xintercept = 0, colour = "red", linetype = "dashed", linewidth = 0.8) +
    facet_wrap(~ comparison, ncol = 1) +
    labs(title = paste("F. Distribution of annual changes across GPs -", label),
      subtitle = "One observation per GP in each distribution",
      x = paste("Annual change in", tolower(y_lab)),
      y = "Number of GP practices") +
    theme_minimal(base_size = 13)

  # ---- Underlying data for release (protected values only, no practice IDs) ----
  panel_data <- df %>%
    arrange(gp_rank, month) %>%
    transmute(
      gp_rank,
      month,
      Y = if_else(redacted, "[REDACTED]", as.character(Y)),
      change_baseline,
      change_yoy
    )

  hist_data <- layer_data(p_F) %>%
    transmute(
      comparison = levels(factor(bind_rows(F_month, F_year)$comparison))[PANEL],
      xmin, xmax,
      n_practices = count
    )

  list(
    plots = list(A = p_A, D1 = p_D1, D2 = p_D2, F = p_F),
    data  = list(panel = panel_data, national = national, hist = hist_data)
  )
}

# -----------------------------------------------------------------------------
# 4. Loop over all 48 series and save (192 graphs + underlying data)
# -----------------------------------------------------------------------------

combos <- expand_grid(
  version   = names(settings),
  measure   = measures,
  condition = c(conditions, "all_conditions")
)

pwalk(combos, function(version, measure, condition) {

  dat <- series %>%
    filter(.data$version == !!version,
      .data$measures == !!measure,
      .data$condition == !!condition)

  if (nrow(dat) == 0) {
    message("Skipping (no data): ", version, " / ", measure, " / ", condition)
    return(invisible(NULL))
  }

  label <- paste(condition_labels[[condition]],
    measure_labels[[measure]],
    setting_labels[[version]], sep = " | ")
  y_lab <- paste0(measure_labels[[measure]],
    if (use_rate) " per 1,000" else "")

  res <- make_panel_plots(dat, label, y_lab)
  plots <- res$plots

  path <- file.path(out_dir, version, measure, condition)
  dir.create(path, recursive = TRUE, showWarnings = FALSE)

  ggsave(file.path(path, "A_spaghetti.png"),         plots$A,  width = 13, height = 7,  dpi = 300)
  ggsave(file.path(path, "D1_baseline_heatmap.png"), plots$D1, width = 13, height = 12, dpi = heatmap_dpi)
  ggsave(file.path(path, "D2_yoy_heatmap.png"),      plots$D2, width = 13, height = 12, dpi = heatmap_dpi)
  ggsave(file.path(path, "F_yoy_distribution.png"),  plots$F,  width = 12, height = 8,  dpi = 300)

  write_csv(res$data$panel,    file.path(path, "A_D1_D2_practice_month_sdc.csv"))
  write_csv(res$data$national, file.path(path, "A_national_mean_sdc.csv"))
  write_csv(res$data$hist,     file.path(path, "F_histogram_bins_sdc.csv"))

  message("Saved: ", label)
})