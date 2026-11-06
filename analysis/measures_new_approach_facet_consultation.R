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
data <- read_csv(
  here("output", "measures_new_approach_consultation_and_medication.csv"),
  show_col_types = FALSE
) %>%
  mutate(interval_start = as.Date(interval_start))

# GP Connect date (vertical line)
GP_connect <- as.Date("2025-10-01")
PF_start <- as.Date("2024-02-01")


message("Number of rows: ", nrow(data))
message("Number of columns: ", ncol(data))

message(
  "Date range: ",
  min(data$interval_start, na.rm = TRUE),
  " to ",
  max(data$interval_start, na.rm = TRUE)
)

print(head(data))



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
# Controls for measures patters
controls <-c("uti","insectbites","sorethroat",
               "vulvovaginalcandidiasis_control",
               "conjunctivitisallergic_control",
               "acutebronchitis_control"
               )

# -----------------------------------------------------------------------------
# 2. Monthly numerators by condition and setting
#    Summing by month and measure gives one total per month even if the
#    measures are later split by group_by (e.g. practice, age band).
# -----------------------------------------------------------------------------
numerators_monthly <- data %>%
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
  numerators_monthly,aes(x = interval_start,y = consultation_count,group = Setting,color = Setting,shape = Setting))+
  geom_line(linewidth = 0.5) +
  geom_point(size = 1) +
  geom_vline(xintercept = GP_connect,linetype = "dashed",linewidth = 0.3) +
  geom_vline(xintercept = PF_start,linetype = "dashed",linewidth = 0.3,color = "blue") +
  facet_wrap(~ condition,scales = "free_y",ncol = 2) +
  scale_x_date(date_labels = "%Y-%m",date_breaks = "2 months") +
  scale_y_continuous( labels = scales::comma) +
  labs(
    title = "Monthly consultation counts across GP practices by condition: GP versus Pharmacy First",
    x = "Month",
    y = "Consultations",
    color = "Setting",
    shape = "Setting"
  )+
  theme(
  # White panel background with a thin black frame
    panel.background = element_rect(fill = "white", colour = NA),
    panel.border     = element_rect(fill = NA, colour = "black", linewidth = 0.4),
    # Light dashed grid lines like in the example
    panel.grid.major = element_line(colour = "grey85", linetype = "dashed", linewidth = 0.3),
    panel.grid.minor = element_blank(),
    # White around the panels and behind the legend keys
    plot.background  = element_rect(fill = "white", colour = NA),
    legend.key       = element_rect(fill = "white", colour = NA),
  # Facet title background and text
  strip.background = element_rect(
    fill = "#037A92",
    colour = "#037A92"
  ),
  strip.text = element_text(
    colour = "white",
    face = "bold"
  ),

  # Legend and axes
  legend.position = "bottom",
  axis.text.x = element_text(angle = 45, hjust = 1)
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

#Section 2: Controls 
# -----------------------------------------------------------------------------
# 2.1.Monthly numerators for control conditions by setting
# -----------------------------------------------------------------------------

numerators_controls <- data %>%
  filter(
    str_detect(
      measure,
      paste0(
        "^(gp|pf)_consultation_(",
        paste(controls, collapse = "|"),
        ")$"
      )
    )
  ) %>%
  group_by(interval_start, measure) %>%
  summarise(
    consultation_count = sum(numerator, na.rm = TRUE),
    .groups = "drop"
  ) %>%
  extract(
    measure,
    into = c("Setting", "condition"),
    regex = "^(gp|pf)_consultation_(.*)$"
  ) %>%
  mutate(
    Setting = case_when(
      Setting == "gp" ~ "GP",
      Setting == "pf" ~ "PF"
    ),
    condition = case_when(
      condition == "uti" ~ "UTI",
      condition == "insectbite" ~ "Insect bites",
      condition == "sorethroat" ~ "Sore throat",
      condition == "vulvovaginalcandidiasis_control" ~
        "Vulvovaginal candidiasis (control)",
      condition == "conjunctivitisallergic_control" ~
        "Allergic conjunctivitis (control)",
      condition == "acutebronchitis_control" ~
        "Acute bronchitis (control)"
    )
  )
#
numerators_paired <- bind_rows(
  numerators_monthly,
  numerators_controls
) %>%
  mutate(
    condition_pair = case_when(
      condition %in% c("UTI", "Vulvovaginal candidiasis (control)") ~
        "UTI vs Vulvovaginal candidiasis",

      condition %in% c("Insect bites", "Allergic conjunctivitis (control)") ~
        "Insect bites vs Allergic conjunctivitis",

      condition %in% c("Sore throat", "Acute bronchitis (control)") ~
        "Sore throat vs Acute bronchitis",

      TRUE ~ NA_character_
    ),
    condition_type = if_else(
      str_detect(condition, "\\(control\\)"),
      "Control",
      "PF condition"
    )
  ) %>%
  filter(!is.na(condition_pair))


  #
  facet_controls_plot <- ggplot(numerators_paired %>%
    filter(Setting == "GP"),aes(
    x = interval_start,
    y = consultation_count,
    #group = condition,
    color = condition_type,
    #linetype = condition_type,
    shape = condition_type
  )) +
  geom_line(linewidth = 0.6) +
  geom_point (size=1.0)+
  geom_vline(xintercept = GP_connect,linetype = "dashed",linewidth = 0.3, color = "grey40") +
  geom_vline(xintercept = PF_start, linetype = "dashed",linewidth = 0.3,color = "blue") +
  facet_wrap( ~condition_pair ,scales = "free_y", ncol = 2) +
  scale_x_date(date_labels = "%Y-%m",date_breaks = "2 months") +
  scale_y_continuous(labels = scales::label_comma()) +
  labs(
    title = "Monthly consultations across general practices : PF conditions and selected controls",
    #subtitle = "Comparison across GP and Pharmacy First settings",
    x = "Month",
    y = "Consultations"#,
    #color = "Setting",
    #linetype = "Condition type"
  ) +
theme(
  # White panel background with a thin black frame
    panel.background = element_rect(fill = "white", colour = NA),
    panel.border     = element_rect(fill = NA, colour = "black", linewidth = 0.4),
    # Light dashed grid lines like in the example
    panel.grid.major = element_line(colour = "grey85", linetype = "dashed", linewidth = 0.3),
    panel.grid.minor = element_blank(),
    # White around the panels and behind the legend keys
    plot.background  = element_rect(fill = "white", colour = NA),
    legend.key       = element_rect(fill = "white", colour = NA),
  # Facet title background and text
  strip.background = element_rect(
    fill = "#037A92",
    colour = "#037A92"
  ),
  strip.text = element_text(
    colour = "white",
    face = "bold"
  ),

  # Legend and axes
  legend.position = "bottom",
  axis.text.x = element_text(angle = 45, hjust = 1)
)   


facet_controls_plot

ggsave(
  filename = here("output", "measures_new_approach_facet_consultation_with_controls.png"),
  plot = facet_controls_plot,
  width = 10,
  height = 6,
  dpi = 300
)







