# ============================================================
# PHARMACY FIRST - GP PRACTICE PANEL VISUALISATIONS
# 3 settings x 2 measures x (7 conditions + total) x 4 graphs
# Based on S. O'Neill's panel code (48 months, ~6,000 practices)
# ============================================================

library(dplyr)
library(tidyr)
library(ggplot2)
library(scales)
library(purrr)

# ------------------------------------------------------------
# 0. SETTINGS - edit these to match your dataset
# ------------------------------------------------------------
# Expected input: ONE long practice-month table with columns
#   practice  : practice identifier
#   month     : 1-48 (integer index; convert dates beforehand)
#   setting   : "GP" or "CP"
#   measure   : "consultations" or "medications"
#   condition : one of the 7 conditions below
#   value     : count for that practice/month/setting/measure/condition
#   list_size : (optional) registered list size, for rates per 1,000


library(readr)
pf_simulated_practice_panel <- read_csv("C:/Users/arnau/Downloads/pf_simulated_practice_panel.csv")

input_data <- pf_simulated_practice_panel          # <- replace with your dataset name




conditions <- c(
  "impetigo", "insect_bites", "otitis_media", "shingles",
  "sinusitis", "sore_throat", "uti"
)
condition_labels <- c(
  impetigo = "Impetigo", insect_bites = "Infected insect bites",
  otitis_media = "Otitis media", shingles = "Shingles",
  sinusitis = "Sinusitis", sore_throat = "Sore throat", uti = "UTI",
  total = "Total (7 conditions)"
)

settings <- list(
  GP_CP = c("GP", "CP"),
  GP    = "GP",
  CP    = "CP"
)
setting_labels <- c(GP_CP = "GP + CP", GP = "GP only", CP = "CP only")

measures <- c("consultations", "medications")
measure_labels <- c(consultations = "Consultations", medications = "Medications")

use_rate     <- FALSE   # TRUE = per 1,000 registered patients (needs list_size)
#out_dir      <- "output/practice_panel"
out_dir      <- "C:/Users/arnau/Downloads"

heatmap_dpi  <- 600     # 600 as in original; 300 is much faster for 96 heatmaps

# ------------------------------------------------------------
# 1. HELPERS
# ------------------------------------------------------------
safe_mean <- function(x) if (all(is.na(x))) NA_real_ else mean(x, na.rm = TRUE)
safe_sum  <- function(x) if (all(is.na(x))) NA_real_ else sum(x, na.rm = TRUE)

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

# ------------------------------------------------------------
# 2. BUILD ALL SERIES (setting version x measure x condition)
# ------------------------------------------------------------
base <- input_data %>%
  mutate(
    practice  = as.character(practice),
    month     = as.integer(month),
    value     = as.numeric(value),
    condition = as.character(condition)
  ) %>%
  filter(!is.na(practice), month %in% 1:48, condition %in% conditions)

build_series <- function(version) {
  by_cond <- base %>%
    filter(setting %in% settings[[version]]) %>%
    group_by(practice, month, measure, condition) %>%
    summarise(
      Y = safe_sum(value),
      list_size = if ("list_size" %in% names(base)) first(list_size) else NA_real_,
      .groups = "drop"
    )

  total <- by_cond %>%
    group_by(practice, month, measure) %>%
    summarise(
      Y = safe_sum(Y),
      list_size = first(list_size),
      .groups = "drop"
    ) %>%
    mutate(condition = "total")

  bind_rows(by_cond, total) %>%
    mutate(
      version = version,
      Y = if (use_rate) 1000 * Y / list_size else Y
    )
}

series <- map_dfr(names(settings), build_series)

# ------------------------------------------------------------
# 3. ONE FUNCTION = THE FOUR GRAPHS FOR ONE SERIES
# ------------------------------------------------------------
make_panel_plots <- function(dat, label, y_lab) {

  df <- dat %>%
    transmute(gp_id = practice, month, Y)

  stopifnot(!anyDuplicated(df[c("gp_id", "month")]))

  # Complete panel so lag(Y, 12) is always 12 calendar months earlier
  df <- df %>%
    complete(gp_id, month = 1:48) %>%
    arrange(gp_id, month) %>%
    group_by(gp_id) %>%
    mutate(
      baseline        = safe_mean(Y[month <= 12]),
      change_baseline = Y - baseline,
      change_yoy      = Y - lag(Y, 12)
    ) %>%
    ungroup()

  # ---- A. Spaghetti ----
  national <- df %>%
    group_by(month) %>%
    summarise(mean_Y = safe_mean(Y), .groups = "drop")

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
  # Practices with no Year-4 data are placed at the BOTTOM
  # (plain arrange() puts NA last = top of the heatmap)
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

  F_year <- df %>%
    filter(month %in% 25:48) %>%
    mutate(period = if_else(month <= 36, "Y3", "Y4")) %>%
    group_by(gp_id, period) %>%
    summarise(mean_Y = safe_mean(Y), n_obs = sum(!is.na(Y)), .groups = "drop") %>%
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

  list(A = p_A, D1 = p_D1, D2 = p_D2, F = p_F)
}

# ------------------------------------------------------------
# 4. LOOP OVER ALL 48 SERIES AND SAVE (192 graphs)
# ------------------------------------------------------------
combos <- expand_grid(
  version   = names(settings),
  measure   = measures,
  condition = c(conditions, "total")
)

pwalk(combos, function(version, measure, condition) {

  dat <- series %>%
    filter(.data$version == !!version,
           .data$measures == !!measures,
           .data$condition == !!condition)

  if (nrow(dat) == 0) {
    message("Skipping (no data): ", version, " / ", measures, " / ", condition)
    return(invisible(NULL))
  }

  label <- paste(condition_labels[[condition]],
                 measure_labels[[measure]],
                 setting_labels[[version]], sep = " | ")
  y_lab <- paste0(measure_labels[[measure]],
                  if (use_rate) " per 1,000" else "")

  plots <- make_panel_plots(dat, label, y_lab)

  path <- file.path(out_dir, version, measure, condition)
  dir.create(path, recursive = TRUE, showWarnings = FALSE)

  ggsave(file.path(path, "A_spaghetti.png"),         plots$A,  width = 13, height = 7,  dpi = 300)
  ggsave(file.path(path, "D1_baseline_heatmap.png"), plots$D1, width = 13, height = 12, dpi = heatmap_dpi)
  ggsave(file.path(path, "D2_yoy_heatmap.png"),      plots$D2, width = 13, height = 12, dpi = heatmap_dpi)
  ggsave(file.path(path, "F_yoy_distribution.png"),  plots$F,  width = 12, height = 8,  dpi = 300)

  message("Saved: ", label)
})
