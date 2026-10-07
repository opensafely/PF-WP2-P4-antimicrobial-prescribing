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
