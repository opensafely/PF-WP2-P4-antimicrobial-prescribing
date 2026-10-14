

library(tidyverse)
library(here)
library(scales)

# -----------------------------------------------------------------------------
# 1. Data
# -----------------------------------------------------------------------------
library(readr)
#measures_new_approach_medication <- read_csv("C:/Users/arnau/Downloads/measures_new_approach_medication.csv")

measures_new_approach <- read_csv(
 here("output", "measures_new_approach_medication.csv"),
 show_col_types = FALSE
) %>%
mutate(interval_start = as.Date(interval_start))

#measures_new_approach<-measures_new_approach_medication %>%
#mutate(interval_start = as.Date(interval_start))

# Key dates 
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
# -----------------------------------------------------------------------------
numerators_monthly <- measures_new_approach %>%
  filter(
    str_detect(
      measure,
      paste0("^(gp|pf)_medication_(", paste(conditions, collapse = "|"), ")$")
    )
  ) %>%
  group_by(interval_start, measure) %>%
  summarise(
    medication_count = sum(numerator, na.rm = TRUE),
    .groups = "drop"
  ) %>%
  extract(
    measure,
    into  = c("Setting", "condition"),
    regex = "^(gp|pf)_medication_(.*)$"
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

# Shared theme
theme_pf <- theme_bw() +
  theme(
    legend.position = "bottom",
    axis.text.x = element_text(angle = 45, hjust = 1),
    strip.text = element_text(face = "bold")
  )

# -----------------------------------------------------------------------------
# 3b. Stacked barplot: monthly volume stacked by condition, GP vs PF
# -----------------------------------------------------------------------------
stacked_data <- numerators_monthly %>%
  filter(condition != "All PF conditions") %>%
  mutate(
    # largest conditions at the bottom of each stack
    condition = fct_reorder(condition, medication_count, .fun = sum, .desc = TRUE)
  )

total_data <- numerators_monthly %>%
  filter(condition == "All PF conditions")

stacked_plot <- ggplot(
  stacked_data,
  aes(x = interval_start, y = medication_count, fill = condition)
) +
  geom_col(width = 25, position = "stack") +            # ~1-month-wide bars
  # geom_line( data = total_data, aes(x = interval_start, y = medication_count),inherit.aes = FALSE,linewidth = 0.4,colour = "black") +
  geom_vline(xintercept = GP_connect, linetype = "dashed", linewidth = 0.3) +
  geom_vline(xintercept = PF_start, linetype = "dashed", linewidth = 0.3, color = "blue") +
  facet_wrap(~ Setting, ncol = 1, scales = "free_y") +
  scale_x_date(date_labels = "%Y-%m", date_breaks = "2 months") +
  scale_y_continuous(labels = comma) +
  scale_fill_brewer(palette = "Set2", name = "Condition") +
  labs(
    title = "Monthly medication volume by condition in both GP and PF settings",
    #subtitle = "Bars: stacked by condition; black line: all PF conditions total",
    x = "Month",
    y = "Medication count"
  ) +
  theme_pf

stacked_plot

ggsave(
  filename = here("output", "measures_new_approach_medication_stacked.png"),
  plot = stacked_plot,
  width = 10,
  height = 7,
  dpi = 300
)

