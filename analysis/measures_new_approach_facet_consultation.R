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
    consultation_count_sdc = apply_sdc(consultation_count, Setting, interval_start),

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
  numerators_monthly,aes(x = interval_start,y = consultation_count_sdc,group = Setting,color = Setting,shape = Setting))+
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
    consultation_count_sdc = apply_sdc(consultation_count, Setting, interval_start),
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
    y = consultation_count_sdc,
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

#ggsave(filename = file.path(output_dir, "measures_new_approach_facet_consultation_with_controls.png"),plot = facet_controls_plot, width = 10,height = 6,dpi = 300)



# =============================================================================
# Pharmacy First — Monthly GP consultations and selected control conditions
# Aggregate practice-level counts, apply SDC, plot and export
# =============================================================================

library(tidyverse)
library(here)

# -----------------------------------------------------------------------------
# 1. Read practice-level data
# -----------------------------------------------------------------------------

practice_level_data_by_practice_only <- read_csv(
  here("output", "practice_level_data_by_practice_only.csv"),
  show_col_types = FALSE
) %>%
  mutate(
    interval_start = as.Date(interval_start)
  )

# -----------------------------------------------------------------------------
# 2. Select GP consultation variables
# -----------------------------------------------------------------------------

consultation_data <- practice_level_data_by_practice_only %>%
  select(
    practice,
    interval_start,
    contains("gp_consultation")
  )

# -----------------------------------------------------------------------------
# 3. Convert to long format and identify conditions and controls
# -----------------------------------------------------------------------------

consultation_data_long <- consultation_data %>%
  pivot_longer(
    cols = starts_with("gp_consultation_"),
    names_to = "condition",
    values_to = "consultation_count"
  ) %>%
  mutate(
    condition = str_remove(
      condition,
      "^gp_consultation_"
    ),

    condition_type = case_when(
      str_detect(condition, "_control$") ~ "control",
      TRUE ~ "PFcondition"
    ),

    condition_pair = case_when(

      condition %in% c(
        "uti",
        "vulvovaginalcandidiasis_control"
      ) ~ "UTI vs vulvovaginal candidiasis",

      condition %in% c(
        "sorethroat",
        "acutebronchitis_control"
      ) ~ "Sore throat vs acute bronchitis",

      condition %in% c(
        "insectbite",
        "conjunctivitisallergic_control"
      ) ~ "Insect bite vs allergic conjunctivitis",

      TRUE ~ NA_character_
    )
  ) %>%
  filter(
    condition %in% c(
      "uti",
      "insectbite",
      "sorethroat",
      "acutebronchitis_control",
      "conjunctivitisallergic_control",
      "vulvovaginalcandidiasis_control"
    )
  )

# -----------------------------------------------------------------------------
# 4. Aggregate consultations across practices by month and condition
# -----------------------------------------------------------------------------

consultation_data_monthly <- consultation_data_long %>%
  group_by(
    interval_start,
    condition,
    condition_type,
    condition_pair
  ) %>%
  summarise(
    consultation_count = sum(
      consultation_count,
      na.rm = TRUE
    ),
    .groups = "drop"
  ) %>%
  arrange(
    condition,
    interval_start
  )

# -----------------------------------------------------------------------------
# 5. Apply statistical disclosure control (SDC)
# -----------------------------------------------------------------------------
# SDC is applied once, after aggregation.
# GP: apply throughout the entire observation period.
# The apply_sdc() function determines suppression, zero retention
# and rounding according to the existing project rules.

consultation_data_monthly_sdc <- consultation_data_monthly %>%
  mutate(
    Setting = "GP",
    consultation_count_sdc = apply_sdc(
      consultation_count,
      Setting,
      interval_start
    )
  )

# -----------------------------------------------------------------------------
# 6. Validate SDC
# -----------------------------------------------------------------------------

sdc_check <- consultation_data_monthly_sdc %>%
  summarise(
    total_rows = n(),

    suppressed = sum(
      is.na(consultation_count_sdc)
    ),

    retained_zeros = sum(
      consultation_count_sdc == 0,
      na.rm = TRUE
    ),

    rounded_counts = sum(
      !is.na(consultation_count_sdc) &
        consultation_count_sdc > 0
    ),

    non_multiple_of_5 = sum(
      !is.na(consultation_count_sdc) &
        consultation_count_sdc > 0 &
        consultation_count_sdc %% 5 != 0
    )
  )

print(sdc_check)

# -----------------------------------------------------------------------------
# 7. Check uniqueness: one observation per month and condition
# -----------------------------------------------------------------------------

duplicate_check <- consultation_data_monthly_sdc %>%
  count(interval_start, condition) %>%
  filter(n > 1)

print(duplicate_check)

# Expected: zero rows.

# -----------------------------------------------------------------------------
# 8. Plot monthly GP consultations
# -----------------------------------------------------------------------------

facet_controls_plot_2 <- ggplot(
  consultation_data_monthly_sdc %>%
    filter(
      condition_pair != "Sore throat vs acute bronchitis"
    ),

  aes(
    x = interval_start,
    y = consultation_count_sdc,
    group = condition,
    color = condition_type,
    shape = condition_type
  )
) +

  geom_line(
    linewidth = 0.6,
    na.rm = TRUE
  ) +

  geom_point(
    size = 1.0,
    na.rm = TRUE
  ) +

  # GP Connect implementation date
  geom_vline(
    xintercept = GP_connect,
    linetype = "dashed",
    linewidth = 0.3,
    color = "grey40"
  ) +

  # Pharmacy First launch date
  geom_vline(
    xintercept = PF_start,
    linetype = "dashed",
    linewidth = 0.3,
    color = "blue"
  ) +

  # Separate condition comparisons
  facet_wrap(
    ~ condition_pair,
    scales = "free_y",
    ncol = 2
  ) +

  scale_x_date(
    date_labels = "%Y-%m",
    date_breaks = "2 months"
  ) +

  scale_y_continuous(
    limits = c(0, NA),
    labels = scales::label_comma(),
    expand = expansion(
      mult = c(0, 0.05)
    )
  ) +

  scale_color_manual(
    values = c(
      "condition" = "#037A92",
      "control" = "#D95F02"
    )
  ) +

  scale_shape_manual(
    values = c(
      "condition" = 16,
      "control" = 17
    )
  ) +

  labs(
    title = paste(
      "Monthly  consultations accross general practices:",
      "PF conditions vs selected potential controls"
    ),

    x = "Month",
    y = "Consultations",

    color = "Condition type",
    shape = "Condition type",

    caption = paste(
  paste(
    "Statistical disclosure control applied:",
    "counts 1–7 suppressed; positive counts rounded to nearest 5.",
    "Zero counts retained.",
    "Suppressed counts are displayed as gaps."
  ),
  paste(
    "Dashed blue line: Pharmacy First launch;",
    "dashed grey line: GP Connect implementation."
  ),
  sep = "\n")
  ) +

  theme(
    # Panel background and border
    panel.background = element_rect(
      fill = "white",
      colour = NA
    ),

    panel.border = element_rect(
      fill = NA,
      colour = "black",
      linewidth = 0.4
    ),

    # Grid lines
    panel.grid.major = element_line(
      colour = "grey85",
      linetype = "dashed",
      linewidth = 0.3
    ),

    panel.grid.minor = element_blank(),

    # Plot background
    plot.background = element_rect(
      fill = "white",
      colour = NA
    ),

    legend.key = element_rect(
      fill = "white",
      colour = NA
    ),

    # Facet titles
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

    axis.text.x = element_text(
      angle = 45,
      hjust = 1
    )
  )

# -----------------------------------------------------------------------------
# 9. Display graph
# -----------------------------------------------------------------------------

print(facet_controls_plot_2)

# -----------------------------------------------------------------------------
# 10. Save graph
# -----------------------------------------------------------------------------

ggsave(
  filename = file.path(
    output_dir,
    "measures_new_approach_facet_consultation_with_controls.png"
  ),

  plot = facet_controls_plot_2,

  width = 10,
  height = 6,
  dpi = 300
)

# -----------------------------------------------------------------------------
# 11. Format SDC-protected data for CSV export
# -----------------------------------------------------------------------------
# IMPORTANT:
# SDC has already been applied in section 5.
# Do not suppress or round the values a second time.

format_sdc_export <- function(df) {

  df %>%
    mutate(
      consultation_count_sdc = case_when(
        is.na(consultation_count_sdc) ~ "[Redacted]",

        consultation_count_sdc == 0 ~ "0",

        TRUE ~ as.character(consultation_count_sdc)
      )
    ) %>%
    select(
      interval_start,
      condition,
      Setting,
      consultation_count_sdc
    ) %>%
    arrange(
      condition,
      Setting,
      interval_start
    )
}




# -----------------------------------------------------------------------------
# Export PF conditions — SDC-protected CSV
# -----------------------------------------------------------------------------

consultation_sdc <- format_sdc_export(
  numerators_monthly
)

write_csv(
  consultation_sdc,
  file.path(
    output_dir,
    "measures_new_approach_facet_consultation_SDC.csv"
  )
)


# -----------------------------------------------------------------------------
# 12. Export control conditions
# -----------------------------------------------------------------------------

consultation_controls_sdc <- format_sdc_export(
  consultation_data_monthly_sdc
)

write_csv(
  consultation_controls_sdc,
  file.path(
    output_dir,
    "measures_new_approach_facet_consultation_controls_SDC.csv"
  )
)

# -----------------------------------------------------------------------------
# 13. Final SDC checks
# -----------------------------------------------------------------------------

final_sdc_check <- consultation_data_monthly_sdc %>%
  group_by(condition, condition_type) %>%
  summarise(
    total_months = n(),

    suppressed_months = sum(
      is.na(consultation_count_sdc)
    ),

    zero_months = sum(
      consultation_count_sdc == 0,
      na.rm = TRUE
    ),

    nonzero_months = sum(
      !is.na(consultation_count_sdc) &
        consultation_count_sdc > 0
    ),

    non_multiple_of_5 = sum(
      !is.na(consultation_count_sdc) &
        consultation_count_sdc > 0 &
        consultation_count_sdc %% 5 != 0
    ),

    .groups = "drop"
  )

print(final_sdc_check)

# =============================================================================
# END
# =============================================================================







