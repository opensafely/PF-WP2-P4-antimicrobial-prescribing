################################################################################
# Regional consultation / medication rates — with Statistical Disclosure Control
################################################################################

library(readr)
library(dplyr)
library(tidyr)
library(ggplot2)
library(forcats)
library(viridis)
library(here)

# ------------------------------------------------------------------------------
# 0. SDC settings and helpers
# ------------------------------------------------------------------------------
# OpenSAFELY approach:
#   (a) redact small counts (1..7) -> NA
#   (b) round the rest to the nearest 5
#   (c) rates are always recomputed FROM the rounded counts
sdc_threshold <- 7
sdc_base      <- 5

apply_sdc <- function(x, threshold = sdc_threshold, base = sdc_base) {
  x   <- as.numeric(x)
  out <- round(x / base) * base                          # nearest 5
  out[!is.na(x) & x > 0 & x <= threshold] <- NA_real_   # redact 1..threshold
  out
}

# ------------------------------------------------------------------------------
# 1. Load and filter
# ------------------------------------------------------------------------------
region_measures <- read_csv(here("output", "region_measures.csv"))

table(region_measures$measure)

region_measure <- region_measures %>%
  filter(trimws(measure) != "appointments_scheduled")

region_measure_consmed <- region_measure %>%
  filter(grepl("^(gp|pf)_(medication|consultation)", measure)) %>%
  filter(!is.na(region)) %>%
  select(-ratio, -practice)

table(region_measure_consmed$measure)

# ------------------------------------------------------------------------------
# 2. Region x month x measure totals (raw — NOT for release)
#    Summing is a no-op if rows are already one per region-month, but protects
#    against any residual sub-region rows.
# ------------------------------------------------------------------------------
region_monthly_raw <- region_measure_consmed %>%
  mutate(
    numerator   = as.numeric(numerator),
    denominator = as.numeric(denominator)
  ) %>%
  group_by(month, region, measure) %>%
  summarise(
    numerator   = sum(numerator,   na.rm = TRUE),
    denominator = sum(denominator, na.rm = TRUE),
    .groups = "drop"
  )

# ------------------------------------------------------------------------------
# 3. Apply SDC and derive labels
# ------------------------------------------------------------------------------
region_monthly_sdc <- region_monthly_raw %>%
  mutate(
    numerator_rounded   = apply_sdc(numerator),
    denominator_rounded = apply_sdc(denominator),
    rate_per_1000_rounded = if_else(
      !is.na(denominator_rounded) & denominator_rounded > 0,
      numerator_rounded / denominator_rounded * 1000,
      NA_real_
    ),
    year = case_when(
      month < as.Date("2023-02-01") ~ "Year 1",
      month < as.Date("2024-02-01") ~ "Year 2",
      month < as.Date("2025-02-01") ~ "Year 3",
      month < as.Date("2026-02-01") ~ "Year 4",
      TRUE ~ NA_character_
    )
  ) %>%
  separate(
    measure,
    into   = c("setting", "service", "condition"),
    sep    = "_",
    extra  = "merge",
    remove = FALSE
  ) %>%
  mutate(
    setting = toupper(setting),
    service = case_when(
      service == "consultation" ~ "Consultation",
      service == "medication"   ~ "Medication"
    )
  ) %>%
  # drop raw counts so they can never be written out by mistake
  select(
    month, year, region, measure, setting, service, condition,
    numerator_rounded, denominator_rounded, rate_per_1000_rounded
  ) %>%
  arrange(measure, region, month)

# Quick check: how much was redacted?
region_monthly_sdc %>%
  summarise(
    n_rows               = n(),
    n_num_redacted       = sum(is.na(numerator_rounded)),
    n_den_redacted       = sum(is.na(denominator_rounded))
  )

# ------------------------------------------------------------------------------
# 4. Write the SDC-safe region monthly table
# ------------------------------------------------------------------------------
output_dir <- here("output")
dir.create(output_dir, showWarnings = FALSE, recursive = TRUE)

write_csv(
  region_monthly_sdc,
  file.path(output_dir, "region_monthly_measures_sdc.csv"),
  na = ""
)

# GP measures
write_csv(
  region_monthly_sdc %>% filter(setting == "GP"),
  file.path(output_dir, "region_monthly_measures_GP_sdc.csv"),
  na = ""
)

# Pharmacy First measures
write_csv(
  region_monthly_sdc %>% filter(setting == "PF"),
  file.path(output_dir, "region_monthly_measures_PF_sdc.csv"),
  na = ""
)

# ------------------------------------------------------------------------------
# 5. Annual rates — built ONLY from SDC'd monthly rates
# ------------------------------------------------------------------------------
region_annual_rates <- region_monthly_sdc %>%
  group_by(setting, service, condition, region, year) %>%
  summarise(
    annual_rate = mean(rate_per_1000_rounded, na.rm = TRUE),
    n_months    = sum(!is.na(rate_per_1000_rounded)),
    .groups = "drop"
  ) %>%
  mutate(
    annual_rate = if_else(n_months == 0, NA_real_, annual_rate),  # avoid NaN
    year    = factor(year, levels = c("Year 1", "Year 2", "Year 3", "Year 4")),
    service = factor(service, levels = c("Consultation", "Medication"))
  )

table(region_annual_rates$condition)

region_annual_rates_1 <- region_annual_rates %>%
  filter(
    !condition %in% c(
      "vulvovaginalcandidiasis_control",
      "acutebronchitis_control",
      "conjunctivitisallergic_control"
    )
  )

# ------------------------------------------------------------------------------
# 6. Plots (unchanged except they now use SDC'd data)
# ------------------------------------------------------------------------------
strip_theme <- theme_bw() +
  theme(
    strip.background = element_rect(fill = "#037A92", colour = "#037A92"),
    strip.text       = element_text(colour = "white", face = "plain"),
    legend.position  = "bottom",
    plot.title       = element_text(face = "bold", hjust = 0.5),
    panel.grid.minor = element_blank()
  )

# 6a. Consultation boxplot
region_annual_rates_1_consultation <- region_annual_rates_1 %>%
  filter(service == "Consultation")

p_region_boxplot_consultation <- ggplot(
  region_annual_rates_1_consultation,
  aes(x = year, y = annual_rate, fill = year)
) +
  geom_boxplot(alpha = 0.75, width = 0.65, outlier.shape = NA) +
  geom_point(
    aes(colour = year),
    position = position_jitter(width = 0.12, height = 0),
    size = 1.8, alpha = 0.7
  ) +
  facet_grid(setting ~ condition, scales = "free_y") +
  scale_fill_brewer(palette = "Blues") +
  scale_colour_brewer(palette = "Blues") +
  labs(
    title  = "Distribution of consultation rates by year",
    x      = "Year",
    y      = " Consultation rate per 1,000 population",
    fill   = "Year",
    colour = "Year"
  ) +
  strip_theme +
  theme(axis.text.x = element_text(angle = 45, hjust = 0.5))

p_region_boxplot_consultation

# 6b. Medication boxplot
region_annual_rates_1_medication <- region_annual_rates_1 %>%
  filter(service == "Medication")

p_region_boxplot_medication <- ggplot(
  region_annual_rates_1_medication,
  aes(x = year, y = annual_rate, fill = year)
) +
  geom_boxplot(alpha = 0.75, width = 0.65, outlier.shape = NA) +
  geom_point(
    aes(colour = year),
    position = position_jitter(width = 0.12, height = 0),
    size = 1.8, alpha = 0.7
  ) +
  facet_grid(setting ~ condition  , scales = "free_y") + ##facet_grid(condition ~ region, scales = "free_y") +
  scale_fill_brewer(palette = "Oranges") +
  scale_colour_brewer(palette = "Oranges") +
  labs(
    title  = "Regional distribution of medication rates by year",
    x      = "Year",
    y      = "Annual medication rate per 1,000 population",
    fill   = "Year",
    colour = "Year"
  ) +
  strip_theme

p_region_boxplot_medication



p_region_boxplot_medication_per_region <- ggplot(
  region_annual_rates_1_medication,
  aes(x = year, y = annual_rate, fill = year)
) +
  geom_boxplot(alpha = 0.75, width = 0.65, outlier.shape = NA) +
  geom_point(
    aes(colour = year),
    position = position_jitter(width = 0.12, height = 0),
    size = 1.8, alpha = 0.7
  ) +
  facet_grid(setting ~ condition , scales = "free_y") + #facet_grid(condition ~ region, scales = "free_y") +
  scale_fill_brewer(palette = "Oranges") +
  scale_colour_brewer(palette = "Oranges") +
  labs(
    title  = "Regional distribution of medication rates by year",
    x      = "Year",
    y      = "Annual medication rate per 1,000 population",
    fill   = "Year",
    colour = "Year"
  ) +
  strip_theme

p_region_boxplot_medication_per_region 

# 6c. Medication heatmap (GP)
region_heatmap_medication <- region_annual_rates_1 %>%
  filter(service == "Medication") %>%
  mutate(region = factor(region, levels = rev(sort(unique(region)))))

p_region_heatmap_medication <- ggplot(
  region_heatmap_medication %>% filter(setting == "GP"),
  aes(x = year, y = region, fill = annual_rate)
) +
  geom_tile(colour = "white", linewidth = 0.3) +
  facet_grid(setting ~ condition, scales = "free_y") +
  scale_fill_viridis_c(
    option   = "C",
    name     = "Annual medication rate\nper 1,000 population",
    na.value = "grey85"
  ) +
  labs(
    title = "Regional variation in annual medication rates",
    x = "Year", y = "Region"
  ) +
  strip_theme +
  theme(
    axis.text.x     = element_text(angle = 45, hjust = 1),
    axis.text.y     = element_text(size = 8),
    legend.position = "right",
    panel.grid      = element_blank()
  )

p_region_heatmap_medication

# ------------------------------------------------------------------------------
# 7. Save figures
# ------------------------------------------------------------------------------
ggsave(file.path(output_dir, "regional_consultation_boxplot.png"),
       p_region_boxplot_consultation,
       width = 16, height = 9, units = "in", dpi = 300, bg = "white")

ggsave(file.path(output_dir, "regional_medication_boxplot.png"),
       p_region_boxplot_medication,
       width = 16, height = 12, units = "in", dpi = 300, bg = "white")

ggsave(file.path(output_dir, "regional_medication_boxplot_region.png"),
       p_region_boxplot_medication_per_region,
       width = 16, height = 12, units = "in", dpi = 300, bg = "white")

       

ggsave(file.path(output_dir, "regional_medication_heatmap_GP.png"),
       p_region_heatmap_medication,
       width = 18, height = 9, units = "in", dpi = 300, bg = "white")