#Monthly and annual medication counts

library(tidyverse)
library(here)
library(lubridate)
library(scales)

# -----------------------------------------------------------------------------
# 1. Read data
# -----------------------------------------------------------------------------

measures_new_approach <- read_csv(
  here("output", "measures_new_approach_medication.csv"),
  show_col_types = FALSE
) %>%
  mutate(interval_start = as.Date(interval_start))

# Important dates
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

# -----------------------------------------------------------------------------
# 2. Define conditions
# -----------------------------------------------------------------------------

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
# 3. Monthly medication counts by condition and setting
# -----------------------------------------------------------------------------

numerators_monthly <- measures_new_approach %>%
  filter(
    str_detect(
      measure,
      paste0(
        "^(gp|pf)_medication_(",
        paste(conditions, collapse = "|"),
        ")$"
      )
    )
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
      uti            = "UTI",
      sinusitis      = "Sinusitis",
      insectbite     = "Insect bites",
      otitismedia    = "Otitis media",
      sorethroat     = "Sore throat",
      shingles       = "Shingles",
      impetigo       = "Impetigo",
      all_conditions = "All PF conditions"
    )
  )

# -----------------------------------------------------------------------------
# 4. Figure 1: Monthly medication counts
# -----------------------------------------------------------------------------

facet_numerators_plot <- ggplot(
  numerators_monthly,
  aes(
    x = interval_start,
    y = medication_count,
    group = Setting,
    color = Setting,
    shape = Setting
  )
) +
  geom_line(linewidth = 0.5) +
  geom_point(size = 1.0) +
  geom_vline(
    xintercept = GP_connect,
    linetype = "dashed",
    linewidth = 0.3
  ) +
  geom_vline(
    xintercept = PF_start,
    linetype = "dashed",
    linewidth = 0.3,
    color = "blue"
  ) +
  facet_wrap(
    ~ condition,
    scales = "free_y",
    ncol = 2
  ) +
  scale_x_date(
    date_labels = "%Y-%m",
    date_breaks = "2 months"
  ) +
  scale_y_continuous(labels = comma) +
  labs(
    title = "Monthly medication counts by condition and setting",
    x = "Month",
    y = "Medication count",
    color = "Setting",
    shape = "Setting"
  ) +
  theme_bw() +
  theme(
    legend.position = "bottom",
    axis.text.x = element_text(angle = 45, hjust = 1),
    strip.text = element_text(face = "bold")
  )

print(facet_numerators_plot)

ggsave(
  filename = here(
    "output",
    "measures_new_approach_facet_medication.png"
  ),
  plot = facet_numerators_plot,
  width = 10,
  height = 6,
  dpi = 300
)


