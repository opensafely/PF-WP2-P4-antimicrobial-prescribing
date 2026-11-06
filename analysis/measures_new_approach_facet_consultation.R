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

output_dir <- here("output", "consultations_counts")
dir.create(
  output_dir,
  recursive = TRUE,
  showWarnings = FALSE
)
# -----------------------------------------------------------------------------#
# SDC function                                                                 #
# Redact counts < 8, retain zeros, round remaining counts to nearest 5         #
# -----------------------------------------------------------------------------#

PF_start <- as.Date("2024-02-01")

apply_sdc <- function(x, setting, interval_start) {
  case_when(
    is.na(x) ~ NA_real_,

    # PF before launch: retain structural zeros
    setting == "PF" & interval_start < PF_start & x == 0 ~ 0,

    # Zero counts: retain
    x == 0 ~ 0,

    # Suppress counts from 1 to 7
    x < 8 ~ NA_real_,

    # Round counts >= 8 to nearest 5
    TRUE ~ round(x / 5) * 5
  )
}




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
  mutate( Setting = case_when(
      Setting == "gp" ~ "GP",
      Setting == "pf" ~ "PF"
    ),
    # Apply SDC
    consultation_count = apply_sdc(consultation_count, Setting, interval_start),

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
  #scale_y_continuous( labels = scales::comma) +
  scale_y_continuous(limits = c(0, NA),labels = scales::label_comma(),expand = expansion(mult = c(0, 0.05)))+
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
  #filename = here("output", "measures_new_approach_facet_consultation.png"),
  filename = file.path(output_dir, "measures_new_approach_facet_consultation.png"),
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
    # Apply SDC : Here because we are using the GP and PF
    consultation_count = apply_sdc(consultation_count, Setting, interval_start),
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
  #scale_y_continuous(labels = scales::label_comma()) +
  scale_y_continuous(limits = c(0, NA),labels = scales::label_comma(),expand = expansion(mult = c(0, 0.05)))+
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
  filename = file.path(output_dir, "measures_new_approach_facet_consultation_with_controls.png"),
  plot = facet_controls_plot,
  width = 10,
  height = 6,
  dpi = 300
)

# -----------------------------------------------------------------------------
# SDC validation
# -----------------------------------------------------------------------------

sdc_check <- bind_rows(
  numerators_monthly %>% mutate(dataset = "PF conditions"),
  numerators_controls %>% mutate(dataset = "Controls")
) %>%
  summarise(
    total_rows = n(),
    suppressed = sum(is.na(consultation_count)),
    retained_zeros = sum(consultation_count == 0, na.rm = TRUE),
    rounded_counts = sum(
      !is.na(consultation_count) &
        consultation_count > 0
    ),
    non_multiple_of_5 = sum(
      !is.na(consultation_count) &
        consultation_count > 0 &
        consultation_count %% 5 != 0
    )
  )

print(sdc_check)


# -----------------------------------------------------------------------------
# 7. Export two separate SDC-protected CSV files
# -----------------------------------------------------------------------------

# SDC formatting function for CSV export
format_sdc_export <- function(df) {
  df %>%
    mutate(
      consultation_count = case_when(
        is.na(consultation_count) ~ "[Redacted]",
        consultation_count == 0 ~ "0",
        consultation_count < 8 ~ "[Redacted]",
        TRUE ~ as.character(round(consultation_count / 5) * 5)
      )
    ) %>%
    select(
      interval_start,
      condition,
      Setting,
      consultation_count
    ) %>%
    arrange(condition, Setting, interval_start)
}

# CSV 1: PF conditions
consultation_sdc <- format_sdc_export(numerators_monthly)

write_csv(
  consultation_sdc,
  file.path(output_dir, "measures_new_approach_facet_consultation_SDC.csv")
)

# CSV 2: Control conditions
consultation_controls_sdc <- format_sdc_export(numerators_controls)

write_csv(
  consultation_controls_sdc,
  file.path(output_dir, "measures_new_approach_facet_consultation_controls_SDC.csv")
)






