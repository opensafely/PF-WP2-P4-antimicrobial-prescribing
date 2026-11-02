

# ------------------------------------------------------------------------------
# ZERO vs NON-ZERO NUMERATOR ANALYSIS
# Monthly and annual practice-level analysis
# Statistical Disclosure Control (SDC)
#
# SDC:
#   Threshold = 8
#   GP = all dates
#   PF = from 2024-02-01
#   Suppressed CSV values = "[Redacted]"
#   Suppressed plot values = NA
#   Remaining counts rounded to nearest 5
#
# Output: output/zero_counts/
#------------------------------------------------------------------------------

# 1. Packages
library(dplyr)
library(tidyr)
library(ggplot2)
library(readr)
library(lubridate)
library(here)
library(scales)
library(stringr)
# 2. SDC parameters

SDC_THRESHOLD <- 8
PF_START <- as.Date("2024-02-01")
REDACTED <- "[Redacted]"

PF_start_date <- as.Date("2024-02-01")
GP_connect_date <- as.Date("2025-10-01")
#---------------------------------------------------------------------------
# 3. Read data
# --------------------------------------------------------------------------
data <- read_csv(
  here("output", "measures_new_approach_consultation_and_medication.csv"),
  show_col_types = FALSE
  ) %>%
  filter(
    #grepl("^(gp|pf)_medication_", measure)
    grepl("^gp_medication_", measure)
  ) %>%
  mutate(
    interval_start = as.Date(interval_start),
    interval_end   = as.Date(interval_end),
    month          = as.Date(month),
    year           = lubridate::year(interval_start)
  )

# -----------------------------------------------------------------------------
# 4. Monthly practice-level classification
# -----------------------------------------------------------------------------
monthly_practice <- data %>%
  group_by(measure, practice, month, year) %>%
  summarise(
    numerator = if (all(is.na(numerator))) {
      NA_real_
    } else {
      sum(numerator, na.rm = TRUE)
    },

    denominator = if (all(is.na(denominator))) {
      NA_real_
    } else {
      sum(denominator, na.rm = TRUE)
    },

    .groups = "drop"
  ) %>%
  mutate(
    zero = if_else(
      is.na(numerator),
      NA_integer_,
      as.integer(numerator == 0)
    ),

    non_zero = if_else(
      is.na(numerator),
      NA_integer_,
      as.integer(numerator > 0)
    ),

    numerator_status = case_when(
      is.na(numerator) ~ NA_character_,
      numerator == 0 ~ "zero",
      numerator > 0 ~ "non_zero",
      TRUE ~ NA_character_
    )
  )

# -----------------------------------------------------------------------------
# 5. Monthly summary
# -----------------------------------------------------------------------------

monthly_summary <- monthly_practice %>%
  filter(!is.na(numerator_status)) %>%
  group_by(measure, month) %>%
  summarise(
    zero_count = sum(zero),
    non_zero_count = sum(non_zero),

    total_practices = n_distinct(practice),

    zero_percentage =
      100 * zero_count / total_practices,

    non_zero_percentage =
      100 * non_zero_count / total_practices,

    .groups = "drop"
  ) %>%
  arrange(measure, month)

# -----------------------------------------------------------------------------
# 6. Annual practice-level classification
# -----------------------------------------------------------------------------
# Annual numerator is the sum of monthly numerators for each practice.
# A practice is classified as zero only if its annual numerator is zero.

annual_practice <- monthly_practice %>%
  group_by(measure, practice, year) %>%
  summarise(
    numerator = if (all(is.na(numerator))) {
      NA_real_
    } else {
      sum(numerator, na.rm = TRUE)
    },

    denominator = if (all(is.na(denominator))) {
      NA_real_
    } else {
      sum(denominator, na.rm = TRUE)
    },

    .groups = "drop"
  ) %>%
  mutate(
    zero = if_else(
      is.na(numerator),
      NA_integer_,
      as.integer(numerator == 0)
    ),

    non_zero = if_else(
      is.na(numerator),
      NA_integer_,
      as.integer(numerator > 0)
    ),

    numerator_status = case_when(
      is.na(numerator) ~ NA_character_,
      numerator == 0 ~ "zero",
      numerator > 0 ~ "non_zero",
      TRUE ~ NA_character_
    )
  )

# -----------------------------------------------------------------------------
# 7. Annual summary
#----------------------------------------------------------------------------
annual_summary <- annual_practice %>%
  filter(!is.na(numerator_status)) %>%
  group_by(measure, year) %>%
  summarise(
    zero_count = sum(zero),
    non_zero_count = sum(non_zero),

    total_practices = n_distinct(practice),

    zero_percentage =
      100 * zero_count / total_practices,

    non_zero_percentage =
      100 * non_zero_count / total_practices,

    .groups = "drop"
  ) %>%
  arrange(measure, year)

# -----------------------------------------------------------------------------
# 8. SDC FUNCTION
# -----------------------------------------------------------------------------

apply_sdc <- function(df, period_date) {

  df %>%
    mutate(

      # Identify measures subject to SDC
      sdc_applies = case_when(

        str_starts(measure, "gp_") ~ TRUE,

        str_starts(measure, "pf_") &
          period_date >= PF_START ~ TRUE,

        TRUE ~ FALSE
      ),

      # Primary suppression:
      # If either category has fewer than 8 practices,
      # suppress BOTH categories and their derived statistics.
      suppress_cell = sdc_applies &
        (
          zero_count < SDC_THRESHOLD |
          non_zero_count < SDC_THRESHOLD
        ),

      # ---------------------------------------------------------
      # Controlled counts for CSV
      # ---------------------------------------------------------

      zero_count_sdc = case_when(

        suppress_cell ~ REDACTED,

        sdc_applies ~ as.character(
          round(zero_count / 5) * 5
        ),

        TRUE ~ as.character(zero_count)
      ),

      non_zero_count_sdc = case_when(

        suppress_cell ~ REDACTED,

        sdc_applies ~ as.character(
          round(non_zero_count / 5) * 5
        ),

        TRUE ~ as.character(non_zero_count)
      ),

      # ---------------------------------------------------------
      # Controlled total practice count
      # ---------------------------------------------------------

      total_practices_sdc = case_when(

        suppress_cell ~ REDACTED,

        sdc_applies ~ as.character(
          round(total_practices / 5) * 5
        ),

        TRUE ~ as.character(total_practices)
      ),

      # ---------------------------------------------------------
      # Controlled percentages
      # ---------------------------------------------------------

      zero_percentage_sdc = case_when(

        suppress_cell ~ NA_real_,

        sdc_applies ~
          round(zero_percentage / 5) * 5,

        TRUE ~ zero_percentage
      ),

      non_zero_percentage_sdc = case_when(

        suppress_cell ~ NA_real_,

        sdc_applies ~
          round(non_zero_percentage / 5) * 5,

        TRUE ~ non_zero_percentage
      )
    )
}

# -----------------------------------------------------------------------------
# 9. Apply SDC to monthly results
# -----------------------------------------------------------------------------

monthly_sdc <- apply_sdc(
  monthly_summary,
  monthly_summary$month
)

# CSV export dataset
monthly_export <- monthly_sdc %>%
  select(
    measure,
    month,
    zero_count = zero_count_sdc,
    non_zero_count = non_zero_count_sdc,
    total_practices = total_practices_sdc,
    zero_percentage = zero_percentage_sdc,
    non_zero_percentage = non_zero_percentage_sdc
  )

# -----------------------------------------------------------------------------
# 10. Apply SDC to annual results
# -----------------------------------------------------------------------------

annual_sdc <- apply_sdc(
  annual_summary,
  as.Date(paste0(annual_summary$year, "-01-01"))
)

# CSV export dataset
annual_export <- annual_sdc %>%
  select(
    measure,
    year,
    zero_count = zero_count_sdc,
    non_zero_count = non_zero_count_sdc,
    total_practices = total_practices_sdc,
    zero_percentage = zero_percentage_sdc,
    non_zero_percentage = non_zero_percentage_sdc
  )

# -----------------------------------------------------------------------------
# 11. Monthly plotting data
# -----------------------------------------------------------------------------

monthly_plot_data <- monthly_sdc %>%
  select(
    measure,
    month,
    zero_percentage = zero_percentage_sdc,
    non_zero_percentage = non_zero_percentage_sdc
  ) %>%
  pivot_longer(
    cols = c(zero_percentage, non_zero_percentage),
    names_to = "status",
    values_to = "percentage"
  ) %>%
  mutate(
    status = recode(
      status,
      zero_percentage = "Zero",
      non_zero_percentage = "Non-zero"
    )
  )

# -----------------------------------------------------------------------------
# 12. Annual plotting data
# -----------------------------------------------------------------------------

annual_plot_data <- annual_sdc %>%
  select(
    measure,
    year,
    zero_percentage = zero_percentage_sdc,
    non_zero_percentage = non_zero_percentage_sdc
  ) %>%
  pivot_longer(
    cols = c(zero_percentage, non_zero_percentage),
    names_to = "status",
    values_to = "percentage"
  ) %>%
  mutate(
    status = recode(
      status,
      zero_percentage = "Zero",
      non_zero_percentage = "Non-zero"
    )
  )

# -----------------------------------------------------------------------------
# 13. Monthly faceted plot
# -----------------------------------------------------------------------------

p_monthly <- ggplot(
  monthly_plot_data,
  aes(
    x = month,
    y = percentage,
    colour = status,
    group = status
  )
) +

  geom_line(
    linewidth = 0.7,
    na.rm = TRUE
  ) +

  geom_point(
    size = 0.8,
    na.rm = TRUE
  ) +

  facet_wrap(
    ~ measure,
    scales = "fixed"
  ) +

  scale_y_continuous(
    limits = c(0, 100),
    breaks = seq(0, 100, 20),
    labels = label_percent(scale = 1)
  ) +

  scale_x_date(
    date_breaks = "2 months",
    date_labels = "%Y-%m"
  ) +

  labs(
    title = "Monthly distribution of practices by numerator status",
    subtitle = paste(
      "Zero versus non-zero numerators;",
      "SDC applied to GP and PF measures"
    ),
    x = "Month",
    y = "Percentage of practices",
    colour = "Numerator status"
  ) +

  theme_bw() +

  theme(
    plot.title = element_text(face = "bold"),
    strip.text = element_text(
      size = 8,
      face = "bold"
    ),
    axis.text.x = element_text(
      angle = 45,
      hjust = 1
    ),
    legend.position = "bottom",
    panel.grid.minor = element_blank()
  )

# -----------------------------------------------------------------------------
# 14. Annual faceted plot
# -----------------------------------------------------------------------------

p_annual <- ggplot(
  annual_plot_data,
  aes(
    x = year,
    y = percentage,
    colour = status,
    group = status
  )
) +

  geom_line(
    linewidth = 0.8,
    na.rm = TRUE
  ) +

  geom_point(
    size = 2,
    na.rm = TRUE
  ) +
  geom_vline(
  xintercept = as.numeric(PF_start_date),
  linetype = "dashed",
  colour = "blue",
  linewidth = 0.7
  ) +
  geom_vline(
  xintercept = as.numeric(GP_connect_date),
  linetype = "dashed",
  colour = "red",
  linewidth = 0.7
  ) +

  facet_wrap(
    ~ measure,
    scales = "fixed"
  ) +

  scale_y_continuous(
    limits = c(0, 100),
    breaks = seq(0, 100, 20),
    labels = label_percent(scale = 1)
  ) +

  scale_x_continuous(
    breaks = pretty_breaks()
  ) +

  labs(
    title = "Annual distribution of practices by numerator status",
    subtitle = paste(
      "Zero versus non-zero annual numerators;",
      "SDC applied to GP and PF measures"
    ),
    x = "Year",
    y = "Percentage of practices",
    colour = "Numerator status"
  ) +

  theme_bw() +

  theme(
    plot.title = element_text(face = "bold"),
    strip.text = element_text(
      size = 8,
      face = "bold"
    ),
    legend.position = "bottom",
    panel.grid.minor = element_blank()
  )

# -----------------------------------------------------------------------------
# 15. Output directory
# -----------------------------------------------------------------------------

output_folder <- here(
  "output",
  "zero_counts"
)

dir.create(
  output_folder,
  recursive = TRUE,
  showWarnings = FALSE
)

# -----------------------------------------------------------------------------
# 16. Export SDC-controlled CSV files
# -----------------------------------------------------------------------------

write_csv(
  monthly_export,
  file.path(
    output_folder,
    "monthly_zero_nonzero_summary_SDC.csv"
  )
)

write_csv(
  annual_export,
  file.path(
    output_folder,
    "annual_zero_nonzero_summary_SDC.csv"
  )
)

# -----------------------------------------------------------------------------
# 17. Export SDC-controlled PNG figures
# -----------------------------------------------------------------------------

ggsave(
  filename = file.path(
    output_folder,
    "monthly_zero_nonzero_faceted_SDC.png"
  ),
  plot = p_monthly,
  width = 18,
  height = 12,
  dpi = 300
)

ggsave(
  filename = file.path(
    output_folder,
    "annual_zero_nonzero_faceted_SDC.png"
  ),
  plot = p_annual,
  width = 18,
  height = 12,
  dpi = 300
)

# -----------------------------------------------------------------------------
# 18. Display plots
# -----------------------------------------------------------------------------

print(p_monthly)
print(p_annual)

# -----------------------------------------------------------------------------
# 19. SDC summary and completion message
# -----------------------------------------------------------------------------

cat("\n============================================\n")
cat("ZERO / NON-ZERO ANALYSIS COMPLETED\n")
cat("============================================\n")

cat("\nSDC threshold:", SDC_THRESHOLD, "\n")
cat("GP: all dates\n")
cat("PF: from", as.character(PF_START), "\n")

cat("\nMonthly suppressed cells:",
    sum(monthly_sdc$suppress_cell), "\n")

cat("Annual suppressed cells:",
    sum(annual_sdc$suppress_cell), "\n")

cat("\nOutput directory:\n")
cat(output_folder, "\n")

cat("\nExported files:\n")
cat("1. monthly_zero_nonzero_summary_SDC.csv\n")
cat("2. annual_zero_nonzero_summary_SDC.csv\n")
cat("3. monthly_zero_nonzero_faceted_SDC.png\n")
cat("4. annual_zero_nonzero_faceted_SDC.png\n")

cat("\n============================================\n")
