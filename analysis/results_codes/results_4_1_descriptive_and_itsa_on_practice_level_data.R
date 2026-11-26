######################################################################
# Pharmacy First — Practice-level data — Medication Analysis
# Author: Arnaud Iradukunda
# Plain R script converted from the R Markdown version.
######################################################################

######################################################################
# Section I. Descriptives analysis
######################################################################
# This section describes medication prescribing for the seven [Pharmacy First]<https://www.england.nhs.uk/primary-care/pharmacy/pharmacy-services/pharmacy-first/> conditions across GP and Pharmacy First (PF) settings. The descriptive analysis summarises the volume and distribution of medication prescribing over time and across practices.

# Monthly medication counts are summarised for each condition and setting, together with the corresponding eligible population. Medication rates are calculated per 1,000 eligible population to account for differences in the size of the eligible population over time and across practices. For each month, the distribution of practice-level medication rates is described using the median, mean, and interquartile range (IQR).

# The analysis presents the prescribing patterns separately for GP and PF settings, allowing the temporal trends and distribution of medication prescribing to be examined before the subsequent comparative and interrupted time-series analyses. These descriptive results provide an overview of the data and help identify notable changes, variation between practices, and differences in prescribing patterns between the two settings.

# The seven PF conditions included in this analysis are urinary tract infection (UTI), sore throat, acute otitis media, impetigo, infected insect bites, shingles, and sinusitis.

# For further details, see the [Github](https://github.com/opensafely/PF-WP2-P4-antimicrobial-prescribing).

######################################################################
# 1. Setup
######################################################################

# ---- setup -----------------------------------------------------------------
library(tidyverse)
library(lubridate)
library(janitor)
library(nlme)
library(geepack)
library(scales)
library(readr)
library(here)
library(broom)
library(gt)

# Folder for saved figures (ggsave/png fail if it does not exist)
dir.create(here::here("output"), showWarnings = FALSE, recursive = TRUE)

######################################################################
# 2. Data and intervention dates
######################################################################

# ---- data ------------------------------------------------------------------
#practice_level_data<- read_csv("C:/Users/arnau/Downloads/practice_level_data_by_practice_only.csv")
#practice_level_data<-read_csv("practice_level_data_by_practice_only.csv")

#
practice_level_data <- read_csv(
  here("output", "practice_level_data_by_practice_only.csv")
)
#
practice_level_data<-practice_level_data%>%
  mutate(interval_start = as.Date(interval_start, format = "%m/%d/%Y"))
GP_connect <- as.Date("2025-10-01")
PF_start   <- as.Date("2024-02-01")
GP_connect
PF_start
min(practice_level_data$interval_start)
max(practice_level_data$interval_start)
library(lubridate)

months <- interval(
  min(practice_level_data$interval_start),
  max(practice_level_data$interval_start)
) %/% months(1) + 1

print(months)
#print(practice_level_data$gp_medication_otitismedia)
#print(practice_level_data$pf_medication_otitismedia)

######################################################################
# mutate(interval_start = as.Date(interval_start))
######################################################################

# ---- data-conditions -------------------------------------------------------
practice_level_data <- practice_level_data %>%
                         clean_names()# From the janitor package and standardises column names (no spaces).

head(practice_level_data)
names(practice_level_data)

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

control_map <- c(
  acutebronchitis_control         = "Acute bronchitis (control)",
  conjunctivitisallergic_control  = "Allergic conjunctivitis (control)",
  vulvovaginalcandidiasis_control = "Vulvovaginal candidiasis (control)"
)

head(practice_level_data)
table(practice_level_data$interval_start)
#names(practice_level_data)

######################################################################
# 3. Monthly totals across practices
######################################################################
# The dataset is aggregated to monthly totals across practices for GP and Pharmacy First (PF) medication counts.

# ---- monthly ---------------------------------------------------------------
monthly <- practice_level_data %>%
  group_by(interval_start) %>%
  summarise(
    population = sum(population, na.rm = TRUE),
    # Eligible populations
    #Conditions specific
    elig_uti         = sum(populationeligible_uuti, na.rm = TRUE),
    elig_sinusitis   = sum(populationeligible_sinusitis, na.rm = TRUE),
    elig_insectbite  = sum(populationeligible_insectbite, na.rm = TRUE),
    elig_otitismedia = sum(populationeligible_otitismedia, na.rm = TRUE),
    elig_sorethroat  = sum(populationeligible_sorethroat, na.rm = TRUE),
    elig_shingles    = sum(populationeligible_shingles, na.rm = TRUE),
    elig_impetigo    = sum(populationeligible_impetigo, na.rm = TRUE),
    # Controls specific
    elig_acutebronchitis_control = sum(populationeligible_acutebronchitis_control, na.rm = TRUE),
    elig_vulvovaginalcandidiasis_control= sum(populationeligible_vulvovaginalcandidiasis_control, na.rm = TRUE),
    elig_conjunctivitisallergic_control = sum(populationeligible_conjunctivitisallergic_control, na.rm = TRUE),
    across(
      starts_with("gp_medication_"),
      ~ sum(.x, na.rm = TRUE)   # This finds all variables whose names start with gp_medication_ and sum each one within each month.
    ),
    across(
      starts_with("pf_medication_"),
      ~ sum(.x, na.rm = TRUE)  #  This finds all variables whose names start with pf_medication_ and sum each one within each month (.x represents the current column being processed).
    ),
    .groups = "drop"          #  This remove the grouping (our dataset is now a normal data frame)
  )

######################################################################
# 0.1. otitis_plot
######################################################################

# ---- otitis_plot -----------------------------------------------------------
# Figure 1. Monthly medication counts for otitis media (GP vs Pharmacy First).
library(dplyr)
library(tidyr)
library(ggplot2)

otitis_monthly <- monthly %>%
  select(
    interval_start,
    gp_medication_otitismedia,
    pf_medication_otitismedia
  ) %>%
  pivot_longer(
    cols = c(
      gp_medication_otitismedia,
      pf_medication_otitismedia
    ),
    names_to = "Setting",
    values_to = "medication_count"
  ) %>%
  mutate(
    Setting = case_when(
     Setting == "gp_medication_otitismedia" ~ "GP",
      Setting == "pf_medication_otitismedia" ~ "PF"
    )
  )
otitis_plot <- ggplot(
  otitis_monthly,
  aes(
    x = interval_start,
    y = medication_count,
    group = Setting,
    color = Setting,
    shape = Setting
  )
) + 
  geom_line(linewidth = 0.5) +
  geom_point(size = 2.5,color="red") +
  geom_vline(xintercept = PF_start, linetype = "dashed", linewidth = 0.6) +
  geom_vline(xintercept = GP_connect, linetype = "dashed", linewidth = 0.6) +
  scale_x_date(date_labels = "%Y-%m", date_breaks = "1 months") +
  labs(
    title = "Monthly medication counts for otitis media",
    x = "Month",
    y = "Medication count"
  ) +
  theme_bw() +
  theme(
    legend.position = "bottom",
    axis.text.x = element_text(angle = 45, hjust = 1)
  )

otitis_plot

# Save as PNG
ggsave(
  filename = "output/results_4_1_Fig1_otitis_monthly_counts.png",
  plot = otitis_plot,
  path = here::here(),
  width = 10,
  height = 6,
  dpi = 300
)

######################################################################
# 0.2. uti_plot
######################################################################

# ---- uti_plot --------------------------------------------------------------
# Figure 2. Monthly medication counts for UTI (GP vs Pharmacy First).
library(dplyr)
library(tidyr)
library(ggplot2)
uti_monthly <- monthly %>%
  select(interval_start,gp_medication_uti,pf_medication_uti) %>%
  pivot_longer(
    cols = c(
      gp_medication_uti,
      pf_medication_uti
    ),
    names_to = "Setting",
    values_to = "medication_count"
  ) %>%
  mutate(
    Setting = case_when(
      Setting == "gp_medication_uti" ~ "GP",
      Setting == "pf_medication_uti" ~ "PF"
    )
  )
uti_plot <- ggplot(
  uti_monthly,
  aes(
    x = interval_start,
    y = medication_count,
    group = Setting,
    color = Setting
  )
) +
  geom_line(linewidth = 0.5) +
  geom_point(size = 2.5, color = "red") +
  geom_vline(xintercept = PF_start, linetype = "dashed", linewidth = 0.6) +
  geom_vline(xintercept = GP_connect, linetype = "dashed", linewidth = 0.6) +
  scale_x_date(date_labels = "%Y-%m", date_breaks = "1 months") +
  labs(
    title = "Monthly medication counts for UTI",
    x = "Month",
    y = "Medication count"
  ) +
  theme_bw() +
  theme(
    legend.position = "bottom"
  )

uti_plot

# Save as PNG
ggsave(
  filename = "output/results_4_1_Fig2_uti_monthly_counts.png",
  plot = uti_plot,
  path = here::here(),
  width = 10,
  height = 6,
  dpi = 300
)

######################################################################
# 0.3. sinusitis_plot
######################################################################

# ---- sinusitis_plot --------------------------------------------------------
# Figure 3. Monthly medication counts for sinusitis (GP vs Pharmacy First).
sinusitis_monthly <- monthly %>%
  select(
    interval_start,
    gp_medication_sinusitis,
    pf_medication_sinusitis
  ) %>%
  pivot_longer(
    cols = c(
      gp_medication_sinusitis,
      pf_medication_sinusitis
    ),
    names_to = "Setting",
    values_to = "medication_count"
  ) %>%
  mutate(
    Setting = case_when(
      Setting == "gp_medication_sinusitis" ~ "GP",
      Setting == "pf_medication_sinusitis" ~ "PF"
    )
  )

sinusitis_plot <- ggplot(
  sinusitis_monthly,
  aes(
    x = interval_start,
    y = medication_count,
    group = Setting,
    color = Setting
  )
) +
  geom_line(linewidth = 1) +
  geom_point(size = 2.5, color = "red") +
  geom_vline(xintercept = PF_start, linetype = "dashed", linewidth = 0.6) +
  geom_vline(xintercept = GP_connect, linetype = "dashed", linewidth = 0.6) +
  scale_x_date(date_labels = "%Y-%m", date_breaks = "1 months") +
  labs(
    title = "Monthly medication counts for sinusitis",
    x = "Month",
    y = "Medication count"
  ) +
  theme_bw() +
  theme(
    legend.position = "bottom",
    axis.text.x = element_text(angle = 45, hjust = 1)
  )

sinusitis_plot

# Save as PNG
ggsave(
  filename = "output/results_4_1_Fig3_sinusitis_monthly_counts.png",
  plot = sinusitis_plot,
  path = here::here(),
  width = 10,
  height = 6,
  dpi = 300
)

######################################################################
# 0.4. insectbite_plot
######################################################################

# ---- insectbite_plot -------------------------------------------------------
# Figure 4. Monthly medication counts for insect bites (GP vs Pharmacy First).
insectbite_monthly <- monthly %>%
  select(
    interval_start,
    gp_medication_insectbite,
    pf_medication_insectbite
  ) %>%
  pivot_longer(
    cols = c(
      gp_medication_insectbite,
      pf_medication_insectbite
    ),
    names_to = "Setting",
    values_to = "medication_count"
  ) %>%
  mutate(
    Setting = case_when(
      Setting == "gp_medication_insectbite" ~ "GP",
      Setting == "pf_medication_insectbite" ~ "PF"
    )
  )

insectbite_plot <- ggplot(
  insectbite_monthly,
  aes(
    x = interval_start,
    y = medication_count,
    group = Setting,
    color = Setting
  )
) +
  geom_line(linewidth = 1) +
  geom_point(size = 2.5, color = "red") +
  geom_vline(xintercept = PF_start, linetype = "dashed", linewidth = 0.6) +
  geom_vline(xintercept = GP_connect, linetype = "dashed", linewidth = 0.6) +
  scale_x_date(date_labels = "%Y-%m", date_breaks = "1 months") +
  labs(
    title = "Monthly medication counts for insect bites",
    x = "Month",
    y = "Medication count"
  ) +
  theme_bw() +
  theme(
    legend.position = "bottom",
    axis.text.x = element_text(angle = 45, hjust = 1)
  )

insectbite_plot

# Save as PNG
ggsave(
  filename = "output/results_4_1_Fig4_insectbite_monthly_counts.png",
  plot = insectbite_plot,
  path = here::here(),
  width = 10,
  height = 6,
  dpi = 300
)

######################################################################
# 0.5. sorethroat_plot
######################################################################

# ---- sorethroat_plot -------------------------------------------------------
# Figure 5. Monthly medication counts for sore throat (GP vs Pharmacy First).
sorethroat_monthly <- monthly %>%
  select(
    interval_start,
    gp_medication_sorethroat,
    pf_medication_sorethroat
  ) %>%
  pivot_longer(
    cols = c(
      gp_medication_sorethroat,
      pf_medication_sorethroat
    ),
    names_to = "Setting",
    values_to = "medication_count"
  ) %>%
  mutate(
    Setting = case_when(
      Setting == "gp_medication_sorethroat" ~ "GP",
      Setting == "pf_medication_sorethroat" ~ "PF"
    )
  )

sorethroat_plot <- ggplot(
  sorethroat_monthly,
  aes(
    x = interval_start,
    y = medication_count,
    group = Setting,
    color = Setting
  )
) +
  geom_line(linewidth = 1) +
  geom_point(size = 2.5, color = "red") +
  geom_vline(xintercept = PF_start, linetype = "dashed", linewidth = 0.6) +
  geom_vline(xintercept = GP_connect, linetype = "dashed", linewidth = 0.6) +
  scale_x_date(date_labels = "%Y-%m", date_breaks = "1 months") +
  labs(
    title = "Monthly medication counts for sore throat",
    x = "Month",
    y = "Medication count"
  ) +
  theme_bw() +
  theme(
    legend.position = "bottom",
    axis.text.x = element_text(angle = 45, hjust = 1)
  )

sorethroat_plot

# Save as PNG
ggsave(
  filename = "output/results_4_1_Fig5_sorethroat_monthly_counts.png",
  plot = sorethroat_plot,
  path = here::here(),
  width = 10,
  height = 6,
  dpi = 300
)

######################################################################
# 0.6. shingles_plot
######################################################################

# ---- shingles_plot ---------------------------------------------------------
# Figure 6. Monthly medication counts for shingles (GP vs Pharmacy First).
shingles_monthly <- monthly %>%
  select(
    interval_start,
    gp_medication_shingles,
    pf_medication_shingles
  ) %>%
  pivot_longer(
    cols = c(
      gp_medication_shingles,
      pf_medication_shingles
    ),
    names_to = "Setting",
    values_to = "medication_count"
  ) %>%
  mutate(
    Setting = case_when(
      Setting == "gp_medication_shingles" ~ "GP",
      Setting == "pf_medication_shingles" ~ "PF"
    )
  )

shingles_plot <- ggplot(
  shingles_monthly,
  aes(
    x = interval_start,
    y = medication_count,
    group = Setting,
    color = Setting
  )
) +
  geom_line(linewidth = 1) +
  geom_point(size = 2.5, color = "red") +
  geom_vline(xintercept = PF_start, linetype = "dashed", linewidth = 0.6) +
  geom_vline(xintercept = GP_connect, linetype = "dashed", linewidth = 0.6) +
  scale_x_date(date_labels = "%Y-%m", date_breaks = "1 months") +
  labs(
    title = "Monthly medication counts for shingles",
    x = "Month",
    y = "Medication count"
  ) +
  theme_bw() +
  theme(
    legend.position = "bottom",
    axis.text.x = element_text(angle = 45, hjust = 1)
  )

shingles_plot

# Save as PNG
ggsave(
  filename = "output/results_4_1_Fig6_shingles_monthly_counts.png",
  plot = shingles_plot,
  path = here::here(),
  width = 10,
  height = 6,
  dpi = 300
)

######################################################################
# 0.7. impetigo_plot
######################################################################

# ---- impetigo_plot ---------------------------------------------------------
# Figure 7. Monthly medication counts for impetigo (GP vs Pharmacy First).
impetigo_monthly <- monthly %>%
  select(
    interval_start,
    gp_medication_impetigo,
    pf_medication_impetigo
  ) %>%
  pivot_longer(
    cols = c(
      gp_medication_impetigo,
      pf_medication_impetigo
    ),
    names_to = "Setting",
    values_to = "medication_count"
  ) %>%
  mutate(
    Setting = case_when(
      Setting == "gp_medication_impetigo" ~ "GP",
      Setting == "pf_medication_impetigo" ~ "PF"
    )
  )

impetigo_plot <- ggplot(
  impetigo_monthly,
  aes(
    x = interval_start,
    y = medication_count,
    group = Setting,
    color = Setting
  )
) +
  geom_line(linewidth = 1) +
  geom_point(size = 2.5, color = "red") +
  geom_vline(xintercept = PF_start, linetype = "dashed", linewidth = 0.6) +
  geom_vline(xintercept = GP_connect, linetype = "dashed", linewidth = 0.6) +
  scale_x_date(date_labels = "%Y-%m", date_breaks = "1 months") +
  labs(
    title = "Monthly medication counts for impetigo",
    x = "Month",
    y = "Medication count"
  ) +
  theme_bw() +
  theme(
    legend.position = "bottom",
    axis.text.x = element_text(angle = 45, hjust = 1)
  )

impetigo_plot

# Save as PNG
ggsave(
  filename = "output/results_4_1_Fig7_impetigo_monthly_counts.png",
  plot = impetigo_plot,
  path = here::here(),
  width = 10,
  height = 6,
  dpi = 300
)

######################################################################
# 0.8. all_conditions_plot
######################################################################

# ---- all_conditions_plot ---------------------------------------------------
# Figure 8. Monthly medication counts for all PF conditions combined (GP vs Pharmacy First).
all_conditions_monthly <- monthly %>%
  select(
    interval_start,
    gp_medication_all_conditions,
    pf_medication_all_conditions
  ) %>%
  pivot_longer(
    cols = c(
      gp_medication_all_conditions,
      pf_medication_all_conditions
    ),
    names_to = "Setting",
    values_to = "medication_count"
  ) %>%
  mutate(
    Setting = case_when(
      Setting == "gp_medication_all_conditions" ~ "GP",
      Setting == "pf_medication_all_conditions" ~ "PF"
    )
  )

all_conditions_plot <- ggplot(
  all_conditions_monthly,   # was impetigo_monthly in the Rmd (bug)
  aes(
    x = interval_start,
    y = medication_count,
    group = Setting,
    color = Setting
  )
) +
  geom_line(linewidth = 1) +
  geom_point(size = 2.5, color = "red") +
  geom_vline(xintercept = PF_start, linetype = "dashed", linewidth = 0.6) +
  geom_vline(xintercept = GP_connect, linetype = "dashed", linewidth = 0.6) +
  scale_x_date(date_labels = "%Y-%m", date_breaks = "1 months") +
  labs(
    title = "Monthly medication counts for all_conditions",
    x = "Month",
    y = "Medication count"
  ) +
  theme_bw() +
  theme(
    legend.position = "bottom",
    axis.text.x = element_text(angle = 45, hjust = 1)
  )

all_conditions_plot

# Save as PNG
ggsave(
  filename = "output/results_4_1_Fig8_all_conditions_monthly_counts.png",
  plot = all_conditions_plot,
  path = here::here(),
  width = 10,
  height = 6,
  dpi = 300
)

######################################################################
# 0.9.condition and controls medication count
######################################################################

######################################################################
# 0.9.1. uti and control_plot
######################################################################

# ---- uti_control_plot ------------------------------------------------------
# Figure 9. Monthly medication counts for UTI vs vulvovaginal candidiasis (control).
uti_control_monthly <- monthly %>%
  select(
    interval_start,
    gp_medication_uti,
    gp_medication_vulvovaginalcandidiasis_control
  ) %>%
  pivot_longer(
    cols = c(
      gp_medication_uti,
    gp_medication_vulvovaginalcandidiasis_control
    ),
    names_to = "Condition",
    values_to = "medication_count"
  ) %>%
  mutate(
    Condition = case_when(
      Condition == "gp_medication_uti" ~ "Uti",
      Condition == "gp_medication_vulvovaginalcandidiasis_control" ~ "vulvovaginalcandidiasis"
    )
  )

uti_control_plot <- ggplot(
  uti_control_monthly,
  aes(
    x = interval_start,
    y = medication_count,
    group = Condition,
    color = Condition,
    linetype = Condition
  )
) +
  geom_line(linewidth = 1) +
  geom_point(size = 2.5, color = "red") +
  geom_vline(xintercept = PF_start, linetype = "dashed", linewidth = 0.6) +
  geom_vline(xintercept = GP_connect, linetype = "dashed", linewidth = 0.6) +
  scale_x_date(date_labels = "%Y-%m", date_breaks = "1 months") +
  labs(
    title = "Monthly medication counts for uti and vulvovaginalis candidiasis (control)",
    x = "Month",
    y = "Medication count",
    linetype = "Condition"
  ) +
  theme_bw() +
  theme(
    legend.position = "bottom",
    axis.text.x = element_text(angle = 45, hjust = 1)
  )

uti_control_plot

# Save as PNG
ggsave(
  filename = "output/results_4_1_Fig9_uti_vs_control.png",
  plot = uti_control_plot,
  path = here::here(),
  width = 10,
  height = 6,
  dpi = 300
)

######################################################################
# 0.9.2. insectbite_control_plot
######################################################################

# ---- insectbite_control_plot -----------------------------------------------
# Figure 10. Monthly medication counts for insect bites vs allergic conjunctivitis (control).
insectbite_control_monthly <- monthly %>%
  select(
    interval_start,
    gp_medication_insectbite,
    gp_medication_conjunctivitisallergic_control
  ) %>%
  pivot_longer(
    cols = c(
      gp_medication_insectbite,
      gp_medication_conjunctivitisallergic_control
    ),
    names_to = "Condition",
    values_to = "medication_count"
  ) %>%
  mutate(
    Condition = case_when(
      Condition == "gp_medication_insectbite" ~ "insect bite",
      Condition == "gp_medication_conjunctivitisallergic_control" ~ "conjunctivitis allergic"
    )
  )

insectbite_control_plot <- ggplot(
  insectbite_control_monthly,
  aes(
    x = interval_start,
    y = medication_count,
    group = Condition,
    color = Condition,
    linetype = Condition
  )
) +
  geom_line(linewidth = 1) +
  geom_point(size = 2.5, color = "red") +
  geom_vline(xintercept = PF_start, linetype = "dashed", linewidth = 0.6) +
  geom_vline(xintercept = GP_connect, linetype = "dashed", linewidth = 0.6) +
  scale_x_date(date_labels = "%Y-%m", date_breaks = "1 months") +
  labs(
    title = "Monthly medication counts for insect bite  and conjunctivitisallergic (control)",
    x = "Month",
    y = "Medication count",
    linetype = "Condition"
  ) +
  theme_bw() +
  theme(
    legend.position = "bottom",
    axis.text.x = element_text(angle = 45, hjust = 1)
  )

insectbite_control_plot

# Save as PNG
ggsave(
  filename = "output/results_4_1_Fig10_insectbite_vs_control.png",
  plot = insectbite_control_plot,
  path = here::here(),
  width = 10,
  height = 6,
  dpi = 300
)

######################################################################
# 0.9.2. sorethroat and control_plot
######################################################################

# ---- sorethroat_control_plot -----------------------------------------------
# Figure 11. Monthly medication counts for sore throat vs acute bronchitis (control).
 sorethroat_control_monthly <- monthly %>%
  select(
    interval_start,
    gp_medication_sorethroat,
    gp_medication_acutebronchitis_control
  ) %>%
  pivot_longer(
    cols = c(
      gp_medication_sorethroat,
      gp_medication_acutebronchitis_control
    ),
    names_to = "Condition",
    values_to = "medication_count"
  ) %>%
  mutate(
    Condition = case_when(
      Condition == "gp_medication_sorethroat" ~ "sorethroat",
      Condition == "gp_medication_acutebronchitis_control" ~ "acute bronchitis"
    )
  )

sorethroat_control_plot <- ggplot(
  sorethroat_control_monthly,
  aes(
    x = interval_start,
    y = medication_count,
    group = Condition,
    color = Condition,
    linetype = Condition
  )
) +
  geom_line(linewidth = 1) +
  geom_point(size = 2.5, color = "red") +
  geom_vline(xintercept = PF_start, linetype = "dashed", linewidth = 0.6) +
  geom_vline(xintercept = GP_connect, linetype = "dashed", linewidth = 0.6) +
  scale_x_date(date_labels = "%Y-%m", date_breaks = "1 months") +
  labs(
    title = "Monthly medication counts for sore throat  and acute bronchitis (control)",
    x = "Month",
    y = "Medication count",
    linetype = "Condition"
  ) +
  theme_bw() +
  theme(
    legend.position = "bottom",
    axis.text.x = element_text(angle = 45, hjust = 1)
  )

sorethroat_control_plot

# Save as PNG
ggsave(
  filename = "output/results_4_1_Fig11_sorethroat_vs_control.png",
  plot = sorethroat_control_plot,
  path = here::here(),
  width = 10,
  height = 6,
  dpi = 300
)

######################################################################
# plot_together(shorter)
######################################################################

# ---- plot_together ---------------------------------------------------------
# Figures 12-19. Monthly medication counts by condition, GP vs Pharmacy First (function-generated versions of Figures 1-8).
plot_gp_pf <- function(data, condition, condition_label) {
  
  plot_data <- data %>%
    select(
      interval_start,
      all_of(paste0("gp_medication_", condition)),
      all_of(paste0("pf_medication_", condition))
    ) %>%
    pivot_longer(
      cols = -interval_start,
      names_to = "Setting",
      values_to = "medication_count"
    ) %>%
    mutate(
      Setting = case_when(
        Setting == paste0("gp_medication_", condition) ~ "GP",
        Setting == paste0("pf_medication_", condition) ~ "PF"
      )
    )
  
  ggplot(
    plot_data,
    aes(
      x = interval_start,
      y = medication_count,
      group = Setting,
      color = Setting,
      shape = Setting
    )
  ) +
    geom_line(linewidth = 0.5) +
    geom_point(size = 2.5, color = "red") +
    geom_vline(xintercept = PF_start, linetype = "dashed", linewidth = 0.6) +
    geom_vline(xintercept = GP_connect, linetype = "dashed", linewidth = 0.6) +
    scale_x_date(
      date_labels = "%Y-%m",
      date_breaks = "1 months"
    ) +
    labs(
      title = paste("Monthly medication counts for", condition_label),
      x = "Month",
      y = "Medication count"
    ) +
    theme_bw() +
    theme(
      legend.position = "bottom",
      axis.text.x = element_text(angle = 45, hjust = 1)
    )
}

plot_together_uti <- plot_gp_pf(monthly, "uti", "UTI")
plot_together_uti
ggsave(filename = "output/results_4_1_Fig12_plot_together_uti.png", plot = plot_together_uti, path = here::here(), width = 10, height = 6, dpi = 300)

plot_together_sinusitis <- plot_gp_pf(monthly, "sinusitis", "sinusitis")
plot_together_sinusitis
ggsave(filename = "output/results_4_1_Fig13_plot_together_sinusitis.png", plot = plot_together_sinusitis, path = here::here(), width = 10, height = 6, dpi = 300)

plot_together_insectbite <- plot_gp_pf(monthly, "insectbite", "insect bites")
plot_together_insectbite
ggsave(filename = "output/results_4_1_Fig14_plot_together_insectbite.png", plot = plot_together_insectbite, path = here::here(), width = 10, height = 6, dpi = 300)

plot_together_otitismedia <- plot_gp_pf(monthly, "otitismedia", "otitis media")
plot_together_otitismedia
ggsave(filename = "output/results_4_1_Fig15_plot_together_otitismedia.png", plot = plot_together_otitismedia, path = here::here(), width = 10, height = 6, dpi = 300)

plot_together_sorethroat <- plot_gp_pf(monthly, "sorethroat", "sore throat")
plot_together_sorethroat
ggsave(filename = "output/results_4_1_Fig16_plot_together_sorethroat.png", plot = plot_together_sorethroat, path = here::here(), width = 10, height = 6, dpi = 300)

plot_together_shingles <- plot_gp_pf(monthly, "shingles", "shingles")
plot_together_shingles
ggsave(filename = "output/results_4_1_Fig17_plot_together_shingles.png", plot = plot_together_shingles, path = here::here(), width = 10, height = 6, dpi = 300)

plot_together_impetigo <- plot_gp_pf(monthly, "impetigo", "impetigo")
plot_together_impetigo
ggsave(filename = "output/results_4_1_Fig18_plot_together_impetigo.png", plot = plot_together_impetigo, path = here::here(), width = 10, height = 6, dpi = 300)

plot_together_all_conditions <- plot_gp_pf(monthly, "all_conditions", "all PF conditions")
plot_together_all_conditions
ggsave(filename = "output/results_4_1_Fig19_plot_together_all_conditions.png", plot = plot_together_all_conditions, path = here::here(), width = 10, height = 6, dpi = 300)

######################################################################
# Faceted plot
######################################################################

# ---- Faceted_plot ----------------------------------------------------------
# Figure 20. Monthly medication counts by condition and setting, faceted by PF condition.
## GP and PF medication counts for all our PF conditions
## Faceted plot
library(dplyr)
library(tidyr)
library(ggplot2)
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
# Long-dataset
all_conditions_monthly <- monthly %>%
  select(
    interval_start,
    matches(
      paste0(
        "^(gp|pf)_medication_(",
        paste(conditions, collapse = "|"),
        ")$"
      )
    )
  ) %>%
  pivot_longer(
    cols = -interval_start,
    names_to = c("Setting", "condition"),
    names_pattern = "^(gp|pf)_medication_(.*)$",
    values_to = "medication_count"
  ) %>%
  mutate(
    Setting = case_when(
      Setting == "gp" ~ "GP",
      Setting == "pf" ~ "PF"
    ),
    
    condition = case_when(
      condition == "uti" ~ "UTI",
      condition == "sinusitis" ~ "Sinusitis",
      condition == "insectbite" ~ "Insect bites",
      condition == "otitismedia" ~ "Otitis media",
      condition == "sorethroat" ~ "Sore throat",
      condition == "shingles" ~ "Shingles",
      condition == "impetigo" ~ "Impetigo",
      condition == "all_conditions" ~ "All PF conditions"
    )
  )

# Faceted plot
faceted_counts_plot <- ggplot(
  all_conditions_monthly,
  aes(
    x = interval_start,
    y = medication_count,
    group = Setting,
    color = Setting,
    shape = Setting
  )
) +
  geom_line(linewidth = 0.5) +
  geom_point(size = 2.5, color = "red") +
  geom_vline(xintercept = PF_start, linetype = "dashed", linewidth = 0.6) +
  geom_vline(xintercept = GP_connect, linetype = "dashed", linewidth = 0.6) +
  facet_wrap(
    ~ condition,
    scales = "free_y",
    ncol = 2
    
  ) +
  scale_x_date(
    date_labels = "%Y-%m",
    date_breaks = "1 months"
  ) +
  labs(
    title = "Monthly medication counts by condition and setting",
    x = "Month",
    y = "Medication count"
  ) +
  theme_bw() +
  theme(
    legend.position = "bottom",
    axis.text.x = element_text(angle = 45, hjust = 1),
    strip.text = element_text(face = "bold")
  )

faceted_counts_plot

# Save as PNG
ggsave(
  filename = "output/results_4_1_Fig20_faceted_counts_by_condition.png",
  plot = faceted_counts_plot,
  path = here::here(),
  width = 10,
  height = 6,
  dpi = 300
)

######################################################################
# summary
######################################################################

# ---- summary ---------------------------------------------------------------
summary(monthly)
names(monthly)

######################################################################
# Montly prescribing rate
######################################################################

# ---- montly_rate -----------------------------------------------------------
montly_rate <- monthly %>%
  mutate(
    # UTI
    gp_rate_uti = (gp_medication_uti / elig_uti) * 1000,
    pf_rate_uti = (pf_medication_uti / elig_uti) * 1000,

    # Sinusitis
    gp_rate_sinusitis = (gp_medication_sinusitis / elig_sinusitis) * 1000,
    pf_rate_sinusitis = (pf_medication_sinusitis / elig_sinusitis) * 1000,

    # Insect bite
    gp_rate_insectbite = (gp_medication_insectbite / elig_insectbite) * 1000,
    pf_rate_insectbite = (pf_medication_insectbite / elig_insectbite) * 1000,

    # Otitis media
    gp_rate_otitismedia = (gp_medication_otitismedia / elig_otitismedia) * 1000,
    pf_rate_otitismedia = (pf_medication_otitismedia / elig_otitismedia) * 1000,

    # Sore throat
    gp_rate_sorethroat = (gp_medication_sorethroat / elig_sorethroat) * 1000,
    pf_rate_sorethroat = (pf_medication_sorethroat / elig_sorethroat) * 1000,

    # Shingles
    gp_rate_shingles = (gp_medication_shingles / elig_shingles) * 1000,
    pf_rate_shingles = (pf_medication_shingles / elig_shingles) * 1000,

    # Impetigo
    gp_rate_impetigo = (gp_medication_impetigo / elig_impetigo) * 1000,
    pf_rate_impetigo = (pf_medication_impetigo / elig_impetigo) * 1000,
    
    # All conditions
    gp_rate_all_conditions = (gp_medication_all_conditions / population) * 1000,
    pf_rate_all_conditions = (pf_medication_all_conditions / population) * 1000
    
    #controls
    #acutebronchitis
    #gp_rate_acutebronchitis = (gp_medication_acutebronchitis_control / elig_sorethroat) * 1000,
    #pf_rate_acutebronchitis = (pf_medication_acutebronchitis_control / elig_sorethroat) * 1000,
    #vulvovaginaliscandidiasis
    #gp_rate_vulvovaginalcandidiasis = (gp_medication_vulvovaginalcandidiasis_control / elig_uti) * 1000,
    #pf_rate_vulvovaginalcandidiasis = (pf_medication_vulvovaginalcandidiasis_control / elig_uti) * 1000,
    # conjunctivitisallergic
    #gp_rate_conjunctivitisallergic = (gp_medication_conjunctivitisallergic_control / elig_sorethroat) * 1000,
    #pf_rate_conjunctivitisallergic = (pf_medication_conjunctivitisallergic_control / elig_sorethroat) * 1000
    )

######################################################################
# Names practice_level_data
######################################################################

# ---- practice_level_data ---------------------------------------------------
names(practice_level_data)

######################################################################
# Montly_prescribing_rate_summary
######################################################################

# ---- montly_prescribing_rate_summary ---------------------------------------
summary_montly_prescribing_rate <- montly_rate %>%
  summarise(
    # UTI
    gp_uti_mean   = mean(gp_rate_uti, na.rm = TRUE),
    gp_uti_median = median(gp_rate_uti, na.rm = TRUE),
    gp_uti_IQR    = IQR(gp_rate_uti, na.rm = TRUE),
    pf_uti_mean   = mean(pf_rate_uti, na.rm = TRUE),
    pf_uti_median = median(pf_rate_uti, na.rm = TRUE),
    pf_uti_IQR    = IQR(pf_rate_uti, na.rm = TRUE),

    # Sinusitis
    gp_sinusitis_mean   = mean(gp_rate_sinusitis, na.rm = TRUE),
    gp_sinusitis_median = median(gp_rate_sinusitis, na.rm = TRUE),
    gp_sinusitis_IQR    = IQR(gp_rate_sinusitis, na.rm = TRUE),
    pf_sinusitis_mean   = mean(pf_rate_sinusitis, na.rm = TRUE),
    pf_sinusitis_median = median(pf_rate_sinusitis, na.rm = TRUE),
    pf_sinusitis_IQR    = IQR(pf_rate_sinusitis, na.rm = TRUE),

    # Insect bite
    gp_insectbite_mean   = mean(gp_rate_insectbite, na.rm = TRUE),
    gp_insectbite_median = median(gp_rate_insectbite, na.rm = TRUE),
    gp_insectbite_IQR    = IQR(gp_rate_insectbite, na.rm = TRUE),
    pf_insectbite_mean   = mean(pf_rate_insectbite, na.rm = TRUE),
    pf_insectbite_median = median(pf_rate_insectbite, na.rm = TRUE),
    pf_insectbite_IQR    = IQR(pf_rate_insectbite, na.rm = TRUE),

    # Otitis media
    gp_otitismedia_mean   = mean(gp_rate_otitismedia, na.rm = TRUE),
    gp_otitismedia_median = median(gp_rate_otitismedia, na.rm = TRUE),
    gp_otitismedia_IQR    = IQR(gp_rate_otitismedia, na.rm = TRUE),
    pf_otitismedia_mean   = mean(pf_rate_otitismedia, na.rm = TRUE),
    pf_otitismedia_median = median(pf_rate_otitismedia, na.rm = TRUE),
    pf_otitismedia_IQR    = IQR(pf_rate_otitismedia, na.rm = TRUE),

    # Sore throat
    gp_sorethroat_mean   = mean(gp_rate_sorethroat, na.rm = TRUE),
    gp_sorethroat_median = median(gp_rate_sorethroat, na.rm = TRUE),
    gp_sorethroat_IQR    = IQR(gp_rate_sorethroat, na.rm = TRUE),
    pf_sorethroat_mean   = mean(pf_rate_sorethroat, na.rm = TRUE),
    pf_sorethroat_median = median(pf_rate_sorethroat, na.rm = TRUE),
    pf_sorethroat_IQR    = IQR(pf_rate_sorethroat, na.rm = TRUE),

    # Shingles
    gp_shingles_mean   = mean(gp_rate_shingles, na.rm = TRUE),
    gp_shingles_median = median(gp_rate_shingles, na.rm = TRUE),
    gp_shingles_IQR    = IQR(gp_rate_shingles, na.rm = TRUE),
    pf_shingles_mean   = mean(pf_rate_shingles, na.rm = TRUE),
    pf_shingles_median = median(pf_rate_shingles, na.rm = TRUE),
    pf_shingles_IQR    = IQR(pf_rate_shingles, na.rm = TRUE),

    # Impetigo
    gp_impetigo_mean   = mean(gp_rate_impetigo, na.rm = TRUE),
    gp_impetigo_median = median(gp_rate_impetigo, na.rm = TRUE),
    gp_impetigo_IQR    = IQR(gp_rate_impetigo, na.rm = TRUE),
    pf_impetigo_mean   = mean(pf_rate_impetigo, na.rm = TRUE),
    pf_impetigo_median = median(pf_rate_impetigo, na.rm = TRUE),
    pf_impetigo_IQR    = IQR(pf_rate_impetigo, na.rm = TRUE),
    
    # All_conditions
    gp_all_conditions_mean   = mean(gp_rate_all_conditions, na.rm = TRUE),
    gp_all_conditions_median = median(gp_rate_all_conditions, na.rm = TRUE),
    gp_all_conditions_IQR    = IQR(gp_rate_all_conditions, na.rm = TRUE),
    pf_all_conditions_mean   = mean(pf_rate_all_conditions, na.rm = TRUE),
    pf_all_conditions_median = median(pf_rate_all_conditions, na.rm = TRUE),
    pf_all_conditions_IQR    = IQR(pf_rate_all_conditions, na.rm = TRUE)
  )

summary(summary_montly_prescribing_rate)

######################################################################
# summary table
######################################################################

# ---- summarytable ----------------------------------------------------------
library(gt)
# Summary table from wide format to long format
summary_gt <- summary_montly_prescribing_rate %>%
  pivot_longer(
    cols = everything(),
    names_to = c("service", "condition", "statistic"),
    names_pattern = "(gp|pf)_(.*)_(mean|median|IQR)"
  ) %>%
  
  # Here i reshape the statistics back into separate columns
  pivot_wider(
    names_from = statistic,
    values_from = value
  ) %>%
  
  # Service and condition names more readable
  mutate(
    service = recode(
      service,
      gp = "GP",
      pf = "Pharmacy First"
    ),
    condition = recode(
      condition,
      uti = "UTI",
      sinusitis = "Sinusitis",
      insectbite = "Insect bite",
      otitismedia = "Otitis media",
      sorethroat = "Sore throat",
      shingles = "Shingles",
      impetigo = "Impetigo",
      all_conditions = "All conditions"
    )
  ) %>%
  
  # i want to Keep only the columns required for the final table
  select(condition, service, mean, median, IQR)

# Formatted gt table
summary_gt %>%
  gt(groupname_col = "condition") %>%
  
  # Columns renamed
  cols_label(
    service = "Service",
    mean = "Mean",
    median = "Median",
    IQR = "IQR"
  ) %>%
  
  # Summary statistics (two decimal places)
  fmt_number(
    columns = c(mean, median, IQR),
    decimals = 2
  ) %>%
  
  # Table title
  tab_header(
    title = "Monthly prescribing rate summary"
  ) %>%
  
  # Centre the service and numerical columns
  cols_align(
    align = "center",
    columns = c(service, mean, median, IQR)
  )

######################################################################
# GP and PF medication rates for all PF conditions
######################################################################

# ---- Faceted_plot_rate -----------------------------------------------------
# Figure 21. Monthly prescribing rates by condition and setting, faceted by PF condition.
## Faceted plot
## GP and PF prescribing rates for all PF conditions

library(dplyr)
library(tidyr)
library(ggplot2)

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

# Long dataset
montly_prescribing_rate_long <- montly_rate %>%
  select(
    interval_start,
    matches(
      paste0(
        "^(gp|pf)_rate_(",
        paste(conditions, collapse = "|"),
        ")$"
      )
    )
  ) %>%
  pivot_longer(
    cols = -interval_start,
    names_to = c("Setting", "condition"),
    names_pattern = "^(gp|pf)_rate_(.*)$",
    values_to = "rate"
  ) %>%
  mutate(
    Setting = case_when(
      Setting == "gp" ~ "GP",
      Setting == "pf" ~ "PF"
    ),
    
    condition = case_when(
      condition == "uti" ~ "UTI",
      condition == "sinusitis" ~ "Sinusitis",
      condition == "insectbite" ~ "Insect bites",
      condition == "otitismedia" ~ "Otitis media",
      condition == "sorethroat" ~ "Sore throat",
      condition == "shingles" ~ "Shingles",
      condition == "impetigo" ~ "Impetigo",
      condition == "all_conditions" ~ "All conditions"
    )
  )

# Faceted plot
faceted_rate_plot <- ggplot(
  montly_prescribing_rate_long,
  aes(
    x = interval_start,
    y = rate,
    group = Setting,
    color = Setting,
    shape = Setting
  )
) +
  geom_line(linewidth = 0.5) +
  geom_point(size = 2.5, color = "red") +
  geom_vline(xintercept = PF_start, linetype = "dashed", linewidth = 0.6) +
  geom_vline(xintercept = GP_connect, linetype = "dashed", linewidth = 0.6) +
  facet_wrap(
    ~ condition,
    scales = "free_y",
    ncol = 2
  ) +
  scale_x_date(
    date_labels = "%Y-%m",
    date_breaks = "1 months"
  ) +
  labs(
    title = "Monthly prescribing rates by condition and setting",
    x = "Month",
    y = "Prescribing rate per 1,000 eligible patients"
  ) +
  theme_bw() +
  theme(
    legend.position = "bottom",
    axis.text.x = element_text(angle = 45, hjust = 1),
    strip.text = element_text(face = "bold")
  )

faceted_rate_plot

# Save as PNG
ggsave(
  filename = "output/results_4_1_Fig21_faceted_rates_by_condition.png",
  plot = faceted_rate_plot,
  path = here::here(),
  width = 10,
  height = 6,
  dpi = 300
)

######################################################################
# Pair rate
######################################################################

######################################################################
# 9. PF medication rate (median, mean, IQR)
######################################################################

# ---- Pair_rate -------------------------------------------------------------
names(montly_rate)
print(montly_rate)

######################################################################
# 9.1.Both GP and PF together
######################################################################

# ---- descr_summary_rate ----------------------------------------------------
descr_summary_rate <- montly_rate %>%
  select (interval_start,gp_rate_otitismedia)%>%
  group_by(interval_start) %>%
  summarise(
    median_rate = median(gp_rate_otitismedia, na.rm = TRUE),
    mean_rate   = mean(gp_rate_otitismedia, na.rm = TRUE),
    q1_rate     = quantile(gp_rate_otitismedia, 0.25, na.rm = TRUE),
    q3_rate     = quantile(gp_rate_otitismedia, 0.75, na.rm = TRUE)
  ) %>%
  ungroup()

descr_summary_rate

######################################################################
# graph_A4_1_medication_rate
######################################################################

# ---- graph_A4_1 ------------------------------------------------------------
# Figure 22. Monthly Pharmacy First prescribing rates, median (solid), mean (dashed), and interquartile range (shaded).
graph_A4_1 <- ggplot(descr_summary_rate, aes(x = interval_start)) +
  geom_ribbon(aes(ymin = q1_rate, ymax = q3_rate,),
              fill = "steelblue", alpha = 0.25) +
  geom_line(aes(y = median_rate), color = "steelblue", linewidth = 1) +
  geom_line(aes(y = mean_rate), color = "red", linetype = "dashed", linewidth = 1) +
  geom_vline(xintercept = as.numeric(PF_start), linetype = "dashed", linewidth = 0.6) +
  # geom_vline(xintercept = as.numeric(GP_connect),linetype = "dotted",linewidth = 0.8) +
  scale_x_date(date_labels = "%b %Y", date_breaks = "1 month") +
  labs(
    title = "Monthly prescribing rate",
    subtitle = "Median (solid line), mean (dashed line), and interquartile range (shaded area)",
    x = "Month",
    y = "Rate per 1,000 eligible population"
  ) +
  theme_bw(base_size = 11) +
  theme(
    axis.text.x = element_text(
      angle = 45,
      hjust = 1
    )
  )
graph_A4_1

# Save as PNG
ggsave(
  filename = "output/results_4_1_Fig22_distribution_rate.png",
  plot = graph_A4_1,
  path = here::here(),
  width = 10,
  height = 6,
  dpi = 300
)

######################################################################
# 9.2.GP vs PF (median, mean, IQR))
######################################################################

# ---- descr_summary_rate_by_settings ----------------------------------------
descr_summary_rate_by_settings <- montly_rate %>%
  select (interval_start,gp_rate_otitismedia,pf_rate_otitismedia)%>%
  group_by(interval_start) %>%
  summarise(
    gp_median_rate = median(gp_rate_otitismedia, na.rm = TRUE),
    gp_mean_rate   = mean(gp_rate_otitismedia, na.rm = TRUE),
    gp_q1_rate     = quantile(gp_rate_otitismedia, 0.25, na.rm = TRUE),
    gp_q3_rate     = quantile(gp_rate_otitismedia, 0.75, na.rm = TRUE),
    
    pf_median_rate = median(pf_rate_otitismedia, na.rm = TRUE),
    pf_mean_rate   = mean(pf_rate_otitismedia, na.rm = TRUE),
    pf_q1_rate     = quantile(pf_rate_otitismedia, 0.25, na.rm = TRUE),
    pf_q3_rate     = quantile(pf_rate_otitismedia, 0.75, na.rm = TRUE)
    
  ) %>%
  ungroup()
names(descr_summary_rate_by_settings)

######################################################################
# graph_A4_by_settings
######################################################################

# ---- graph_A4_by_settings --------------------------------------------------
# Figure 23. Monthly medication rate, GP vs Pharmacy First: median (solid), mean (dashed), and interquartile range (shaded).
graph_A4_2_by_settings <- ggplot(descr_summary_rate_by_settings,aes(x = interval_start)) +
  #GP interquartile range
  geom_ribbon(aes(ymin = gp_q1_rate,ymax = gp_q3_rate),fill = "steelblue",alpha = 0.2) +
  # PF interquartile range
  geom_ribbon(aes(ymin = pf_q1_rate,ymax = pf_q3_rate ),fill = "firebrick",alpha = 0.2) +
  # GP median
  geom_line(aes(y = gp_median_rate,colour = "GP",linetype = "Median"),linewidth = 1) +
  # GP mean
  geom_line(aes(y = gp_mean_rate,colour = "GP",linetype = "Mean" ), linewidth = 1) +
  # PF median
  geom_line(aes(y = pf_median_rate, colour = "PF",linetype = "Median"),linewidth = 1 ) +
  # PF mean
  geom_line( aes(y = pf_mean_rate,colour = "PF",linetype = "Mean"),linewidth = 1) +
  scale_colour_manual(values = c("GP" = "steelblue", "PF" = "firebrick")) +
  scale_linetype_manual(values = c("Median" = "solid","Mean" = "dashed")) +
  scale_x_date(date_labels = "%b %Y",date_breaks = "1 month") +
  labs(
    title = "Monthly medication rate: GP vs PF",
    subtitle = "Median (solid line) and mean (dashed line), with interquartile range (shaded), per 1,000 eligible population",
    x = "Month",
    y = "Rate per 1,000 eligible population",
    colour = "Setting",
    fill = "Setting",
    linetype = "Statistic"
  ) +

  theme_bw(base_size = 11) +

  theme(axis.text.x = element_text(angle = 45,hjust = 1))

graph_A4_2_by_settings
# Save as PNG
ggsave(
  filename = "output/results_4_1_Fig23_medication_rate_gp_vs_pf.png",
  plot = graph_A4_2_by_settings,
  path = here::here(),
  width = 10,
  height = 6,
  dpi = 300
)

######################################################################
# Section II. ITSA models — GP
######################################################################
# The following section prepares an interrupted time-series analysis for all seven Pharmacy First conditions.
# The intervention is **PF service implementation on 1 february 2024**.
# However,**GP Connect on 1 October 2025** may influence reported data in GP records.

# We model the monthly GP-recorded medication counts using a segmented
# Poisson regression with an offset for the population at risk.

# The model specification is:

# \[
# \log\left(E(Y_{gt})\right)
# =
# \beta_0
# +
# \beta_1 T_{gt}
# +
# \beta_2 X_{gt}
# +
# \beta_3 X_{gt}T_{gt}
# +
# \log(Pop_{gt})
# \]

# where:

# - \(Y_{gt}\) is the observed count of the outcome for practice \(g\) at month \(t\);
# - \(E(Y_{gt})\) is the expected count;
# - \(T_{gt}\) is the time in months from the start of the study period;
# - \(X_{gt}\) is an indicator for the post-intervention period
# (\(1\) = at/after PF service implementation, \(0\) = before);
# - \(X_{gt}T_{gt}\) is the interaction term allowing the slope to change after the intervention;
# - \(Pop_{gt}\) is the population at risk for practice \(g\) at month \(t\), included as an offset.

# - `β0` = baseline level of the outcome at the start of the study period;
# - `β1` = baseline time trend (change in the outcome per month before PF service);
# - `β2` = immediate level change in the outcome following PF service implementation;
# - `β3` = change in the time trend (slope) following PF service implementation.

######################################################################
# 8.1 Prepare ITSA dataset
######################################################################

# ---- PrepareITSAdataset ----------------------------------------------------
#names(practice_level_data)
# GP Connect intervention date
#intervention_date <- as.Date("2025-10-01")
intervention_date <- as.Date("2024-02-01")
#ITSA dataset

practice_level_data_itsa <- practice_level_data %>%
  mutate( interval_start = as.Date(interval_start)) %>%
  arrange(practice,interval_start) %>%
  group_by(practice) %>%
  mutate(
    # Time starts at 1 for each practice
    T = row_number()-1,
    # Intervention start
    X = as.integer(interval_start >= intervention_date),
    # Time point of intervention
    first_post_T = T[interval_start == intervention_date][1],
    # Change in slope after  intervention
    XT = pmax(
      T - first_post_T,
      0
    ) * X
  ) %>%
  ungroup() %>%
  select(-first_post_T)

# Check data
print(head(practice_level_data_itsa, 14))

# Check ITSA variables
print(
  practice_level_data_itsa %>%
    distinct(interval_start, T, X, XT) %>%
    arrange(interval_start)
)
# Export into csv
#write_csv(practice_level_data_itsa,"practice_level_da

######################################################################
# II.GEE models:
######################################################################

######################################################################
# All Data
######################################################################

# ---- All_Data --------------------------------------------------------------
practice_level_data_itsa

######################################################################
# II.1.GP UTI medication prescribing
######################################################################

# ---- gee_uti_data ----------------------------------------------------------
# 1. Load packages
library(dplyr)
library(ggplot2)
library(lubridate)
library(geepack)
library(broom)
gee_uti_data <- practice_level_data_itsa %>%
  select(
    practice,
    interval_start,
    population,
    populationeligible_uuti,
    gp_medication_uti,T,
    X,
    XT
  )
gee_uti_data

######################################################################
# 3. Data checks
######################################################################

# ---- data-check ------------------------------------------------------------
glimpse(gee_uti_data)
summary(gee_uti_data$gp_medication_uti)
summary(gee_uti_data$populationeligible_uuti)
table(gee_uti_data$X)
range(gee_uti_data$interval_start, na.rm = TRUE)

######################################################################
# 4.Missing and invalid values
######################################################################

# ---- missingness -----------------------------------------------------------
 gee_uti_data %>%
  summarise(
    n_rows = n(),
    n_practices = n_distinct(practice),
    n_na = sum(is.na(gp_medication_uti)),
    n_nan = sum(is.nan(gp_medication_uti)),
    n_inf = sum(is.infinite(gp_medication_uti)),
    min = min(gp_medication_uti, na.rm = TRUE),
    max = max(gp_medication_uti, na.rm = TRUE),
    missing_outcome = sum(is.na(gp_medication_uti)),
    missing_population = sum(is.na(population)),
    missing_eligible_population = sum(is.na(populationeligible_uuti)),
    zero_population = sum(population <= 0, na.rm = TRUE),
    zero_eligible_population = sum(populationeligible_uuti <= 0, na.rm = TRUE),
    missing_date = sum(is.na(interval_start))
  )

######################################################################
# 5. Fit the GEE model
######################################################################

# ---- GEE model -------------------------------------------------------------
class(gee_uti_data$population)
names(gee_uti_data$population)

######################################################################
# gee_uti_model
######################################################################

# ---- gee_uti_model ---------------------------------------------------------
gee_uti_model <- geeglm(
  gp_medication_uti ~ T + X + XT,
  family = poisson(link = "log"),
  offset = log(population), # I used pop because the eligible pop contains zero
  id = practice,
  corstr = "ar1",
  data = gee_uti_data
)

######################################################################
# 6. Model summary
######################################################################

# ---- model_summary ---------------------------------------------------------
summary(gee_uti_model)

######################################################################
# 7.Fitted values from the GEE model
######################################################################

# ---- plot-gee-uti-post-trend -----------------------------------------------
# Figure 24. GP medications for UTI — observed values and GEE fitted trend.
gee_uti_plot_data <- gee_uti_data %>%
  mutate(
    fitted_rate = predict( gee_uti_model,type = "response"),fitted_count = fitted_rate 
    )

gee_uti_trend_plot <- ggplot(gee_uti_plot_data,aes(x = interval_start)) +
   # Observed monthly medications
  geom_point(aes(y = gp_medication_uti), size = 1.5, alpha = 0.6
    ) +
  # Observed line
  geom_line(aes(y = gp_medication_uti),linewidth = 0.6, alpha = 0.5) +
  # GEE fitted trend
  geom_line(aes(y = fitted_count),linewidth = 1) +
  # GP Connect intervention
  geom_vline(xintercept = as.numeric(PF_start), linetype = "dashed", linewidth = 0.6) +
  # geom_vline(xintercept = as.numeric(GP_connect),linetype = "dotted",linewidth = 0.8) +
  scale_x_date(date_labels = "%Y-%m-%d", date_breaks = "1 months") +
  labs(
    title = "GP medications for UTI",
    subtitle = "Observed values and GEE fitted trend",
    x = NULL,
    y = "Number of medications"
  ) +
  
  theme_minimal(base_size = 11) +
  
  theme(
    axis.text.x = element_text(
      angle = 45,
      hjust = 1
    )
  )
gee_uti_trend_plot

# Save as PNG
ggsave(
  filename = "output/results_4_1_Fig24_gee_uti_observed_vs_fitted.png",
  plot = gee_uti_trend_plot,
  path = here::here(),
  width = 10,
  height = 6,
  dpi = 300
)

######################################################################
# 7. Incidence-rate ratios (IRRs)
######################################################################

# ---- irr -------------------------------------------------------------------
irr_results <- broom::tidy(
  gee_uti_model,
  exponentiate = TRUE,
  conf.int = TRUE
)

irr_results

######################################################################
# 8. Extract the main Pharmacy First effects
######################################################################

# ---- pf_effects ------------------------------------------------------------
pf_effects <- irr_results %>%
  filter(term %in% c( "T","X", "XT")) %>%
  select(
    term,
    estimate,
    conf.low,
    conf.high,
    p.value
  )

pf_effects

######################################################################
# 9.Table
######################################################################

# ---- pf_effects_table ------------------------------------------------------
pf_effects %>%
  mutate(
    IRR = round(estimate, 3),
    CI = paste0(
      round(conf.low, 3),
      "–",
      round(conf.high, 3)
    ),
    p_value = signif(p.value, 3)
  ) %>%
  select(
    term,
    IRR,
    CI,
    p_value
  )

######################################################################
# 10. Observed monthly GP UTI medication rate
######################################################################

# ---- observed_rate ---------------------------------------------------------
monthly_uti <- gee_uti_data %>%
  group_by(interval_start) %>%
  summarise(
    gp_medication_uti = sum(
      gp_medication_uti,
      na.rm = TRUE
    ),

    population = sum(
      population,
      na.rm = TRUE
    ),

    rate_per_1000 = (
      gp_medication_uti / population
    ) * 1000,

    .groups = "drop"
  )

######################################################################
# 11. Visualise observed prescribing rate
######################################################################

# ---- observed_rate_plot ----------------------------------------------------
# Figure 25. GP UTI antimicrobial prescribing — monthly rate before and after Pharmacy First implementation.
observed_rate_plot <- ggplot( monthly_uti, aes(x = interval_start, y = rate_per_1000)) +
   geom_line(linewidth = 0.8) +
   geom_point(size = 1.5) +
   # Pharmacy First implementation
  geom_vline( xintercept = as.numeric(as.Date("2025-10-01")),
    linetype = "dashed",
    linewidth = 0.8 
    ) +
  scale_x_date(date_labels = "%Y-%m", date_breaks = "1 months") +
  annotate(
    "text",
    x = as.Date("2025-10-01"),
    y = Inf,
    label = "Pharmacy First",
    vjust = 1.5,
    hjust = -0.05
  ) +

  labs(
    title = "GP UTI antimicrobial prescribing",
    subtitle = "Monthly prescribing rate before and after Pharmacy First implementation",
    x = "Month",
    y = "GP UTI medication prescriptions per 1,000 population"
  ) +
  theme_minimal() +
  theme(
    plot.title = element_text(face = "bold"),
    axis.text.x = element_text(angle = 45, hjust = 1)
  )

observed_rate_plot

# Save as PNG
ggsave(
  filename = "output/results_4_1_Fig25_gp_uti_prescribing_rate.png",
  plot = observed_rate_plot,
  path = here::here(),
  width = 10,
  height = 6,
  dpi = 300
)

######################################################################
# 12.Fitted/predicted trend from the GEE model
######################################################################

# ---- predicted_trend -------------------------------------------------------
gee_uti <- gee_uti_data %>%
  mutate(
    predicted_rate_per_1000 =
      predict(
        gee_uti_model,
        type = "response"
      ) /
      population * 1000
  )

######################################################################
# II.Controlled ITSA
######################################################################

# ---- ControlledITSA --------------------------------------------------------

names(practice_level_data)

######################################################################
# data-uti_and_control
######################################################################

# ---- data-uti_and_control --------------------------------------------------
practice_level_uti_and_control_long <- practice_level_data %>%
  select(
    practice,
    interval_start,
    population,
    populationeligible_uuti,
    gp_medication_uti,
    gp_medication_vulvovaginalcandidiasis_control
     )%>%
  pivot_longer(
    cols = c(
      gp_medication_uti,
      gp_medication_vulvovaginalcandidiasis_control
    ),
    names_to = "condition",
    values_to = "medication_count"
  ) %>%
  mutate( interval_start = as.Date(interval_start)) %>%
  arrange(practice,interval_start) %>%
  group_by(practice,condition) %>% # :By both practice.condition because each       practice now has two rows per month:
                                    #         —one for UTI and one for control
                                    #         —T will increase twice per month. 
  mutate(
    # Time starts at 1 for each practice
    T = row_number()-1,
    # Intervention start
    X = as.integer(interval_start >= intervention_date),
    # Time point of intervention
    first_post_T = T[interval_start == intervention_date][1],
    # Change in slope after  intervention
    XT = pmax(T - first_post_T, 0 ) * X ) %>%
    # Multiple-group ITS interaction terms
    # Z = 1 for UTI, 0 for control
    mutate( Z = as.integer(condition == "gp_medication_uti"),
    ZT  = Z * T,
    ZX  = Z * X,
    ZXT = Z * XT
    ) %>%
    ungroup() %>%
  select(-first_post_T)
print(
  practice_level_uti_and_control_long %>%
    select(practice,condition,interval_start,T,X,XT,Z,ZT,ZX, ZXT)
)

######################################################################
# ITSA controlled model
######################################################################

######################################################################
# gee_uti_model
######################################################################

# ---- gee_uti_controlled_model ----------------------------------------------
gee_uti_controlled_model <- geeglm(
  medication_count ~ T + X + XT + ZT + ZX + ZXT ,
  family = poisson(link = "log"),
  offset = log(population), # I used pop because the eligible pop contains zero
  id = practice,
  corstr = "ar1",
  data = practice_level_uti_and_control_long
)
summary(gee_uti_controlled_model)
exp(gee_uti_controlled_model$coefficients)

######################################################################
# 2.Coefficient table with exponentiated rate ratios + CIs
######################################################################

# ---- Coefficient_table -----------------------------------------------------

broom::tidy(gee_uti_controlled_model, exponentiate = TRUE, conf.int = TRUE)

######################################################################
# 2. Post-intervention trend comparisons
######################################################################

# ---- Post-intervention-trend-comparison ------------------------------------

lincom <- function(model, terms, level = 0.95) {
  b <- coef(model)
  V <- vcov(model)
  cv <- setNames(rep(0, length(b)), names(b))
  cv[terms] <- 1

  est <- sum(cv * b)
  se  <- sqrt(t(cv) %*% V %*% cv)[1, 1]
  z   <- est / se
  p   <- 2 * pnorm(-abs(z))
  ci  <- est + c(-1, 1) * qnorm(1 - (1 - level) / 2) * se

  data.frame(Estimate = est, SE = se, z = z, `Pr(>|z|)` = p,
             CI.lower = ci[1], CI.upper = ci[2],
             RateRatio = exp(est), RR.lower = exp(ci[1]), RR.upper = exp(ci[2]),
             check.names = FALSE)
}

trend_results <- rbind(
  Treatment    = lincom(gee_uti_controlled_model, c("T", "ZT", "XT", "ZXT")),
  Control      = lincom(gee_uti_controlled_model, c("T", "XT")),
  Difference = lincom(gee_uti_controlled_model, c("ZT", "ZXT"))
)
trend_results

######################################################################
# post_estimation_trends-plot
######################################################################

# ---- post_estimation_trends-plot -------------------------------------------
# Figure 26. Post-estimation trends: UTI (treatment) vs vulvovaginal candidiasis (control).

library(dplyr)
library(ggplot2)

plot_data <- practice_level_uti_and_control_long %>%
  mutate(fitted_rate = predict(gee_uti_controlled_model, type = "response") / population) %>%
  group_by(interval_start, Z) %>%
  summarise(
    actual_rate    = sum(medication_count) / sum(population),
    predicted_rate = weighted.mean(fitted_rate, population),
    .groups = "drop"
  ) %>%
  mutate(group_label = if_else(Z == 1, "Treatment", "Control"))

intervention_date <- as.Date("2025-10-01")  #

post_estimation_trend_plot <- ggplot(plot_data, aes(x = interval_start, colour = group_label, group = group_label)) +
  geom_point(aes(y = actual_rate, shape = group_label), size = 2) +
  geom_line(aes(y = predicted_rate, linetype = group_label)) +
  geom_vline(xintercept = as.numeric(intervention_date), linetype = "dotted") +
  scale_x_date(date_labels = "%Y-%m", date_breaks = "1 months") +
  scale_shape_manual(values = c(Treatment = 16, Control = 1)) +
  scale_linetype_manual(values = c(Treatment = "solid", Control = "dashed")) +
  labs(
    title = "Urinary tract infections (Treatment) vs. Vulvovaginalis-candidiasis (Control)",
    subtitle = paste("GP connect starts:", format(intervention_date, "%Y-%m-%d")),
    x = "Month", y = "Rate (medications per population)",
    colour = "Group", shape = "Group", linetype = "Group"
  ) +
  #theme_minimal()+
  theme(axis.text.x = element_text(angle = 45, hjust = 1))

post_estimation_trend_plot

# Save as PNG
ggsave(
  filename = "output/results_4_1_Fig26_post_estimation_trends.png",
  plot = post_estimation_trend_plot,
  path = here::here(),
  width = 10,
  height = 6,
  dpi = 300
)

######################################################################
# 3.Model-checking
######################################################################

# ---- Model-checking --------------------------------------------------------

library(geepack)
library(dplyr)
# ---- 0.  candidate model (baseline for reference) ----------------------------
fit_ar1 <- geeglm(
  medication_count ~ T + X + XT + ZT + ZX + ZXT,
  family  = poisson(link = "log"),
  offset  = log(population),
  id      = practice,
  waves   = T,          # time index column
  corstr  = "ar1",
  data    = practice_level_uti_and_control_long
)

# 1. QIC — compare working correlation structures
#    (GEE has no likelihood, so no AIC/BIC — use QIC instead)

fit_indep <- geeglm(
  medication_count ~ T + X + XT + ZT + ZX + ZXT,
  family = poisson(link = "log"),
  offset = log(population),
  id = practice, waves = T,
  corstr = "independence",
  data = practice_level_uti_and_control_long
)

fit_exch <- geeglm(
  medication_count ~ T + X + XT + ZT + ZX + ZXT,
  family = poisson(link = "log"),
  offset = log(population),
  id = practice, waves = T,
  corstr = "exchangeable",
  data = practice_level_uti_and_control_long
)

QIC(fit_ar1)
QIC(fit_exch)
QIC(fit_indep)

# Tabulate side by side
qic_table <- tibble(
  structure = c("ar1", "exchangeable", "independence"),
  QIC       = c(QIC(fit_ar1)["QIC"], QIC(fit_exch)["QIC"], QIC(fit_indep)["QIC"])
)
qic_table %>% arrange(QIC)
# Lower QIC = better trade-off of fit vs. complexity. Pick that structure.

######################################################################
# 2. Estimated within-cluster correlation (alpha)
######################################################################

# ---- corr ------------------------------------------------------------------
summary(fit_ar1)$corr        # the estimated correlation parameter(s)
# For ar1, one alpha = lag-1 correlation. Near 0 -> independence would suffice.

######################################################################
# 3. Dispersion / overdispersion check
######################################################################

# ---- dispersion ------------------------------------------------------------
summary(fit_ar1)$dispersion

######################################################################
# Manual Pearson-based check (rule of thumb: >1.5-2 = meaningful overdispersion)
######################################################################

# ---- pearson_resid ---------------------------------------------------------
pearson_resid <- residuals(fit_ar1, type = "pearson")
n_params <- length(coef(fit_ar1))
n_obs    <- length(pearson_resid)
dispersion_manual <- sum(pearson_resid^2) / (n_obs - n_params)
dispersion_manual

######################################################################
# 4. Residual diagnostics
######################################################################

# ---- residual-diagnostics-data ---------------------------------------------
df_diag <- practice_level_uti_and_control_long %>%
  mutate(
    pearson_resid = residuals(fit_ar1, type = "pearson"),
    fitted_vals   = fitted(fit_ar1)
  )

# ---- residuals-vs-fitted ---------------------------------------------------
# Figure 27. Residuals vs fitted values from the AR(1) GEE model.
# Residuals vs fitted (look for trend/funnel = misspecified mean or variance)

# Save as PNG
png(here::here("output", "results_4_1_Fig27_residuals_vs_fitted.png"), width = 10, height = 6, units = "in", res = 300)
plot(df_diag$fitted_vals, df_diag$pearson_resid,
     xlab = "Fitted values", ylab = "Pearson residuals",
     main = "Residuals vs Fitted")
abline(h = 0, col = "red", lty = 2)
dev.off()

plot(df_diag$fitted_vals, df_diag$pearson_resid,
     xlab = "Fitted values", ylab = "Pearson residuals",
     main = "Residuals vs Fitted")
abline(h = 0, col = "red", lty = 2)

# ---- residuals-vs-time -----------------------------------------------------
# Figure 28. Residuals vs time from the AR(1) GEE model.
# Residuals vs time

# Save as PNG
png(here::here("output", "results_4_1_Fig28_residuals_vs_time.png"), width = 10, height = 6, units = "in", res = 300)
plot(df_diag$T, df_diag$pearson_resid,
     xlab = "Time", ylab = "Pearson residuals",
     main = "Residuals vs Time")
abline(h = 0, col = "red", lty = 2)
dev.off()

plot(df_diag$T, df_diag$pearson_resid,
     xlab = "Time", ylab = "Pearson residuals",
     main = "Residuals vs Time")
abline(h = 0, col = "red", lty = 2)

# ---- residuals-by-practice -------------------------------------------------
# Figure 29. Pearson residuals over time by practice.
# Residuals by practice (spot clusters with systematically poor fit)
library(ggplot2)
residuals_by_practice_plot <- ggplot(df_diag, aes(x = T , y = pearson_resid, group = practice)) +
  geom_line(alpha = 0.2) +
  geom_hline(yintercept = 0, color = "red", linetype = "dashed") +
  labs(title = "Pearson residuals over time by practice")

residuals_by_practice_plot

# Save as PNG
ggsave(
  filename = "output/results_4_1_Fig27_residuals_by_practice.png",
  plot = residuals_by_practice_plot,
  path = here::here(),
  width = 10,
  height = 6,
  dpi = 300
)

######################################################################
# 6. Sensitivity check:
######################################################################

######################################################################
# do effect estimates change much across correlation structure choices?
######################################################################

# ---- bind_rows -------------------------------------------------------------
# Figure 28. Sensitivity of rate-ratio estimates to the working correlation structure (exponentiated).

sensitivity_plot_exp <- bind_rows(
  tidy(fit_ar1,   exponentiate = TRUE, conf.int = TRUE) %>% mutate(structure = "ar1"),
  tidy(fit_exch,  exponentiate = TRUE, conf.int = TRUE) %>% mutate(structure = "exchangeable"),
  tidy(fit_indep, exponentiate = TRUE, conf.int = TRUE) %>% mutate(structure = "independence")
) %>%
  filter(term != "(Intercept)") %>%
  ggplot(aes(x = term, y = estimate, color = structure)) +
  geom_pointrange(aes(ymin = conf.low, ymax = conf.high),
                   position = position_dodge(width = 0.5)) +
  geom_hline(yintercept = 1, linetype = "dashed") +
  coord_flip() +
  labs(y = "Rate ratio (95% CI)", x = NULL,
       title = "Sensitivity of estimates to working correlation structure")

sensitivity_plot_exp

# Save as PNG
ggsave(
  filename = "output/results_4_1_Fig28_sensitivity_correlation_structure_rr.png",
  plot = sensitivity_plot_exp,
  path = here::here(),
  width = 10,
  height = 6,
  dpi = 300
)

######################################################################
# bind_rows_1
######################################################################

# ---- bind_rows_1 -----------------------------------------------------------
# Figure 29. Sensitivity of rate-ratio estimates to the working correlation structure (manually exponentiated).

sensitivity_plot_manual_exp <- bind_rows(
  tidy(fit_ar1,   conf.int = TRUE) %>% mutate(structure = "ar1"),
  tidy(fit_exch,  conf.int = TRUE) %>% mutate(structure = "exchangeable"),
  tidy(fit_indep, conf.int = TRUE) %>% mutate(structure = "independence")
) %>%
  mutate(estimate = exp(estimate),
         conf.low  = exp(conf.low),
         conf.high = exp(conf.high)) %>%
  filter(term != "(Intercept)") %>%
  ggplot(aes(x = term, y = estimate, color = structure)) +
  geom_pointrange(aes(ymin = conf.low, ymax = conf.high),
                   position = position_dodge(width = 0.5)) +
  geom_hline(yintercept = 1, linetype = "dashed") +
  coord_flip() +
  labs(y = "Rate ratio (95% CI)", x = NULL,
       title = "Sensitivity of estimates to working correlation structure (manually exponentiated)")

sensitivity_plot_manual_exp

# Save as PNG
ggsave(
  filename = "output/results_4_1_Fig29_sensitivity_correlation_structure_rr_manual.png",
  plot = sensitivity_plot_manual_exp,
  path = here::here(),
  width = 10,
  height = 6,
  dpi = 300
)




#II.Modelling ITSA




######################################################################
# Pharmacy First — Practice-level data — GEE ITSA by condition
# Author: Arnaud Iradukunda
#
# Part A. Single-group ITSA (Poisson GEE) for each of the 7 PF conditions
# Part B. Controlled ITSA (Poisson GEE) for the 3 conditions with a control:
#           UTI          vs vulvovaginal candidiasis
#           Insect bite  vs allergic conjunctivitis
#           Sore throat  vs acute bronchitis
# Part C. Model assessment for every model:
#           QIC across working correlations, alpha, dispersion,
#           residual plots, ACF / Ljung-Box on monthly residuals,
#           sensitivity of IRRs to correlation structure,
#           (optional) sensitivity truncating at GP Connect.
#
# Model (single group), practice g, month t:
#   log E(Y_gt) = b0 + b1*T + b2*X + b3*XT [+ seasonality] + log(offset_gt)
#   b1 = pre-PF monthly trend, b2 = immediate level change at PF start,
#   b3 = change in monthly trend after PF start
#
# Model (controlled), condition-series c (Z = 1 PF condition, 0 control):
#   log E(Y) = b0 + b1*T + b2*X + b3*XT
#            + b4*Z + b5*ZT + b6*ZX + b7*ZXT [+ seasonality] + log(offset)
#   b4 = baseline level difference, b5 = pre-trend difference,
#   b6 = difference in level change (PF condition vs control),
#   b7 = difference in trend change (PF condition vs control)
#
# All outputs go to output/gee/
######################################################################

# ---- setup -----------------------------------------------------------------
suppressPackageStartupMessages({
  library(dplyr)
  library(tidyr)
  library(purrr)
  library(readr)
  library(ggplot2)
  library(lubridate)
  library(geepack)
  library(broom)
  library(here)
})

######################################################################
# 0. Configuration — edit here
######################################################################

data_path <- here("output", "practice_level_data_by_practice_only.csv")
# data_path <- "C:/Users/arnau/Downloads/practice_level_data_by_practice_only (7).csv"

PF_start   <- as.Date("2024-02-01")   # intervention
GP_connect <- as.Date("2025-10-01")   # recording change in GP records

# Offset: "population" (total list size; your current choice because some
# eligible populations are 0) or "eligible" (condition-specific eligible
# population; rows with eligible population <= 0 are dropped, since
# nobody is at risk there).
offset_type <- "population"

adjust_season <- TRUE      # add annual Fourier terms (sin/cos 12 months)
main_corstr   <- "ar1"     # working correlation for the main models
corstrs       <- c("ar1", "exchangeable", "independence")
run_gp_connect_sensitivity <- TRUE   # refit using months before GP Connect only

out_dir <- here("output", "gee")
dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)

# Conditions: name in data -> label, outcome column, eligible-pop column
conditions <- tribble(
  ~cond,          ~label,              ~elig_var,
  "uti",          "UTI",               "populationeligible_uuti",   # 'uuti' as named in the data
  "sinusitis",    "Sinusitis",         "populationeligible_sinusitis",
  "insectbite",   "Insect bite",       "populationeligible_insectbite",
  "otitismedia",  "Otitis media",      "populationeligible_otitismedia",
  "sorethroat",   "Sore throat",       "populationeligible_sorethroat",
  "shingles",     "Shingles",          "populationeligible_shingles",
  "impetigo",     "Impetigo",          "populationeligible_impetigo"
) %>%
  mutate(med_var = paste0("gp_medication_", cond))

# PF condition -> control pairs
pairs <- tribble(
  ~cond,        ~control,                          ~control_label,
  "uti",        "vulvovaginalcandidiasis_control", "Vulvovaginal candidiasis",
  "insectbite", "conjunctivitisallergic_control",  "Allergic conjunctivitis",
  "sorethroat", "acutebronchitis_control",         "Acute bronchitis"
) %>%
  left_join(conditions %>% select(cond, label, med_var, elig_var), by = "cond") %>%
  mutate(
    control_med_var  = paste0("gp_medication_", control),
    control_elig_var = paste0("populationeligible_", control)
  )

######################################################################
# 1. Load data and build the time variables
######################################################################

# ---- data ------------------------------------------------------------------
clean_names_simple <- function(df) {
  if (requireNamespace("janitor", quietly = TRUE)) return(janitor::clean_names(df))
  names(df) <- tolower(gsub("[^A-Za-z0-9]+", "_", names(df)))
  df
}

dat_raw <- read_csv(data_path, show_col_types = FALSE) %>% clean_names_simple()

# Dates arrive as m/d/Y in some extracts and Y-m-d in others
dat_raw <- dat_raw %>%
  mutate(interval_start = as.Date(parse_date_time(
    as.character(interval_start), orders = c("ymd", "mdy", "dmy")
  )))

stopifnot(!any(is.na(dat_raw$interval_start)))

study_start <- min(dat_raw$interval_start)
T_PF        <- interval(study_start, PF_start) %/% months(1)

# T, X, XT are defined from the calendar, not from row numbers, so a
# practice with a missing month keeps the right time index.
dat <- dat_raw %>%
  mutate(
    T  = interval(study_start, interval_start) %/% months(1),
    X  = as.integer(interval_start >= PF_start),
    XT = pmax(T - T_PF, 0),
    sin12 = sin(2 * pi * month(interval_start) / 12),
    cos12 = cos(2 * pi * month(interval_start) / 12),
    practice_id = as.integer(factor(practice))
  )

cat("Study period:", format(study_start), "to", format(max(dat$interval_start)),
    "| months:", max(dat$T) + 1, "| PF at T =", T_PF, "\n")
print(dat %>% distinct(interval_start, T, X, XT) %>% arrange(interval_start), n = Inf)

season_terms <- if (adjust_season) " + sin12 + cos12" else ""

######################################################################
# 2. Helper functions
######################################################################

# ---- helpers ---------------------------------------------------------------

# One condition series: outcome y, offset, time variables. Drops invalid rows
# and sorts by cluster then time (geeglm requires contiguous, ordered clusters).
prep_series <- function(data, med_var, elig_var) {
  out <- data %>%
    transmute(
      practice, practice_id, interval_start, T, X, XT, sin12, cos12,
      y = .data[[med_var]],
      pop = if (offset_type == "eligible") .data[[elig_var]] else population
    ) %>%
    filter(!is.na(y), !is.na(pop), pop > 0) %>%
    mutate(log_pop = log(pop)) %>%
    arrange(practice_id, T)
  out
}

data_checks <- function(d, name) {
  tibble(
    model = name,
    n_rows = nrow(d),
    n_practices = n_distinct(d$practice_id),
    n_months = n_distinct(d$T),
    total_count = sum(d$y),
    prop_zero = mean(d$y == 0),
    min_y = min(d$y), max_y = max(d$y),
    n_pre = sum(d$X == 0), n_post = sum(d$X == 1)
  )
}

# geeglm evaluates id/waves inside `data`, so the columns are named directly.
fit_gee <- function(formula, d, corstr, id_col = "practice_id") {
  d$cluster <- d[[id_col]]
  d <- d %>% arrange(cluster, T)
  fit <- tryCatch(
    geeglm(formula, family = poisson(link = "log"), data = d,
           id = cluster, waves = T, corstr = corstr),
    error = function(e) { message("  fit failed (", corstr, "): ", conditionMessage(e)); NULL }
  )
  # QIC refits an independence model from the call, so it must run here,
  # where `d` and `formula` exist
  if (!is.null(fit)) {
    fit$qic <- tryCatch(QIC(fit, env = environment()),
                        error = function(e) { message("  QIC failed: ", conditionMessage(e)); rep(NA_real_, 6) })
  }
  fit
}

tidy_irr <- function(fit, model_name, corstr) {
  if (is.null(fit)) return(NULL)
  tidy(fit, exponentiate = TRUE, conf.int = TRUE) %>%
    mutate(model = model_name, corstr = corstr, .before = 1)
}

# Linear combination of coefficients (robust vcov), on the log and IRR scale
lincom <- function(model, terms, level = 0.95) {
  b  <- coef(model); V <- vcov(model)
  cv <- setNames(rep(0, length(b)), names(b)); cv[terms] <- 1
  est <- sum(cv * b)
  se  <- sqrt(as.numeric(t(cv) %*% V %*% cv))
  ci  <- est + c(-1, 1) * qnorm(1 - (1 - level) / 2) * se
  tibble(estimate_log = est, se = se, z = est / se, p.value = 2 * pnorm(-abs(est / se)),
         IRR = exp(est), IRR_low = exp(ci[1]), IRR_high = exp(ci[2]))
}

# Diagnostics for one fitted model: dispersion, alpha, QIC, residual checks
assess_fit <- function(fit, d, model_name, corstr) {
  if (is.null(fit)) return(NULL)
  pr  <- residuals(fit, type = "pearson")
  qic <- fit$qic
  alpha <- if (length(fit$geese$alpha)) unname(fit$geese$alpha[1]) else NA_real_

  # Residual autocorrelation on the monthly aggregated residual series
  monthly_res <- tibble(T = d$T, r = pr) %>% group_by(T) %>%
    summarise(r = mean(r), .groups = "drop") %>% arrange(T)
  lb <- tryCatch(Box.test(monthly_res$r, lag = min(12, nrow(monthly_res) - 2),
                          type = "Ljung-Box"), error = function(e) NULL)

  tibble(
    model = model_name, corstr = corstr,
    QIC = unname(qic[1]), QICu = unname(qic[2]), CIC = unname(qic[4]),
    alpha = alpha,
    dispersion_gee = summary(fit)$dispersion$Estimate[1],
    dispersion_pearson = sum(pr^2) / (length(pr) - length(coef(fit))),
    ljung_box_p = if (is.null(lb)) NA_real_ else lb$p.value,
    acf_lag1_monthly = acf(monthly_res$r, plot = FALSE, lag.max = 1)$acf[2]
  )
}

save_plot <- function(p, file, w = 10, h = 6) {
  ggsave(file.path(out_dir, file), p, width = w, height = h, dpi = 300)
}

residual_plots <- function(fit, d, model_name, file_stub) {
  df <- d %>% mutate(pr = residuals(fit, type = "pearson"), fv = fitted(fit))

  p1 <- ggplot(df, aes(fv, pr)) +
    geom_point(alpha = 0.15, size = 0.6) +
    geom_hline(yintercept = 0, colour = "red", linetype = "dashed") +
    scale_x_log10() +
    labs(title = paste(model_name, "— Pearson residuals vs fitted"),
         x = "Fitted count (log scale)", y = "Pearson residual") +
    theme_bw()

  p2 <- df %>% group_by(interval_start) %>%
    summarise(mean = mean(pr), q1 = quantile(pr, .25), q3 = quantile(pr, .75), .groups = "drop") %>%
    ggplot(aes(interval_start, mean)) +
    geom_ribbon(aes(ymin = q1, ymax = q3), alpha = 0.2) +
    geom_line() + geom_point(size = 1.5) +
    geom_hline(yintercept = 0, colour = "red", linetype = "dashed") +
    geom_vline(xintercept = PF_start, linetype = "dashed") +
    geom_vline(xintercept = GP_connect, linetype = "dotted") +
    scale_x_date(date_labels = "%Y-%m", date_breaks = "2 months") +
    labs(title = paste(model_name, "— Pearson residuals over time"),
         subtitle = "Mean (line) and IQR (band) across practices",
         x = NULL, y = "Pearson residual") +
    theme_bw() + theme(axis.text.x = element_text(angle = 45, hjust = 1))

  monthly_r <- df %>% group_by(T) %>% summarise(r = mean(pr), .groups = "drop") %>% arrange(T)
  a <- acf(monthly_r$r, plot = FALSE, lag.max = min(18, nrow(monthly_r) - 1))
  ci <- qnorm(0.975) / sqrt(nrow(monthly_r))
  p3 <- tibble(lag = a$lag[-1], acf = a$acf[-1]) %>%
    ggplot(aes(lag, acf)) +
    geom_hline(yintercept = 0) +
    geom_hline(yintercept = c(-ci, ci), linetype = "dashed", colour = "blue") +
    geom_segment(aes(xend = lag, yend = 0)) +
    labs(title = paste(model_name, "— ACF of monthly mean Pearson residuals"),
         x = "Lag (months)", y = "ACF") +
    theme_bw()

  save_plot(p1, paste0(file_stub, "_resid_vs_fitted.png"))
  save_plot(p2, paste0(file_stub, "_resid_vs_time.png"))
  save_plot(p3, paste0(file_stub, "_resid_acf.png"), w = 8, h = 5)
}

######################################################################
# Part A. Single-group ITSA — 7 PF conditions
######################################################################

# ---- single-group-models ---------------------------------------------------
f_single <- as.formula(paste0("y ~ T + X + XT", season_terms, " + offset(log_pop)"))

single_irr   <- list()
single_diag  <- list()
single_check <- list()
single_fits  <- list()

for (i in seq_len(nrow(conditions))) {
  cc <- conditions[i, ]
  message("Single-group GEE: ", cc$label)
  d <- prep_series(dat, cc$med_var, cc$elig_var)
  single_check[[cc$cond]] <- data_checks(d, cc$label)

  fits <- set_names(map(corstrs, ~ fit_gee(f_single, d, .x)), corstrs)
  single_fits[[cc$cond]] <- list(data = d, fits = fits)

  single_irr[[cc$cond]]  <- imap_dfr(fits, ~ tidy_irr(.x, cc$label, .y))
  single_diag[[cc$cond]] <- imap_dfr(fits, ~ assess_fit(.x, d, cc$label, .y))

  main <- fits[[main_corstr]]
  if (is.null(main)) next

  # Observed vs fitted vs counterfactual (no PF: X = XT = 0), per 1,000
  cf <- d %>% mutate(X = 0, XT = 0)
  plot_df <- d %>%
    mutate(fitted = predict(main, type = "response"),
           counterfactual = predict(main, newdata = cf, type = "response")) %>%
    group_by(interval_start) %>%
    summarise(across(c(y, fitted, counterfactual), sum), pop = sum(pop), .groups = "drop") %>%
    mutate(across(c(y, fitted, counterfactual), ~ .x / pop * 1000),
           counterfactual = if_else(interval_start >= PF_start, counterfactual, NA_real_))

  p_fit <- ggplot(plot_df, aes(interval_start)) +
    geom_point(aes(y = y, colour = "Observed"), size = 2) +
    geom_line(aes(y = fitted, colour = "GEE fitted"), linewidth = 1) +
    geom_line(aes(y = counterfactual, colour = "Counterfactual (no PF)"),
              linetype = "dashed", linewidth = 0.9, na.rm = TRUE) +
    geom_vline(xintercept = PF_start, linetype = "dashed") +
    geom_vline(xintercept = GP_connect, linetype = "dotted") +
    scale_colour_manual(values = c("Observed" = "grey30", "GEE fitted" = "#2166AC",
                                   "Counterfactual (no PF)" = "#B2182B")) +
    scale_x_date(date_labels = "%Y-%m", date_breaks = "2 months") +
    labs(title = paste("GP medications for", cc$label, "— single-group ITSA"),
         subtitle = paste0("Poisson GEE (", main_corstr, "), offset = ", offset_type,
                           "; dashed = PF start, dotted = GP Connect"),
         x = NULL, y = paste("Medications per 1,000", offset_type), colour = NULL) +
    theme_bw() + theme(legend.position = "bottom",
                       axis.text.x = element_text(angle = 45, hjust = 1))
  save_plot(p_fit, paste0("A_", cc$cond, "_observed_fitted.png"))

  residual_plots(main, d, cc$label, paste0("A_", cc$cond))

  # Sensitivity: months before GP Connect only
  if (run_gp_connect_sensitivity) {
    d_pre <- d %>% filter(interval_start < GP_connect)
    fit_pre <- fit_gee(f_single, d_pre, main_corstr)
    single_irr[[paste0(cc$cond, "_preGPC")]] <-
      tidy_irr(fit_pre, cc$label, paste0(main_corstr, " (pre-GP Connect)"))
  }
}

single_irr_all   <- bind_rows(single_irr)
single_diag_all  <- bind_rows(single_diag)
single_check_all <- bind_rows(single_check)

write_excel_csv(single_check_all, file.path(out_dir, "A_data_checks.csv"))
write_excel_csv(single_irr_all,   file.path(out_dir, "A_single_irr_all_structures.csv"))
write_excel_csv(single_diag_all,  file.path(out_dir, "A_single_diagnostics.csv"))

# Main results table (main correlation structure, PF terms only)
term_labels <- c(T = "Pre-PF trend (per month)",
                 X = "Level change at PF start",
                 XT = "Change in trend after PF (per month)")

single_main_table <- single_irr_all %>%
  filter(corstr == main_corstr, term %in% names(term_labels)) %>%
  transmute(condition = model, term = term_labels[term],
            IRR = round(estimate, 3),
            `95% CI` = sprintf("%.3f–%.3f", conf.low, conf.high),
            p = signif(p.value, 3))
write_excel_csv(single_main_table, file.path(out_dir, "A_single_main_table.csv"))
print(single_main_table, n = Inf)

# Forest plot across the 7 conditions
p_forest_A <- single_irr_all %>%
  filter(corstr == main_corstr, term %in% names(term_labels)) %>%
  mutate(term = factor(term_labels[term], levels = term_labels),
         model = factor(model, levels = rev(conditions$label))) %>%
  ggplot(aes(estimate, model)) +
  geom_vline(xintercept = 1, linetype = "dashed", colour = "grey40") +
  geom_errorbarh(aes(xmin = conf.low, xmax = conf.high), height = 0.2) +
  geom_point(size = 2.5, colour = "#2166AC") +
  facet_wrap(~ term, scales = "free_x") +
  scale_x_log10() +
  labs(title = "Single-group ITSA — incidence rate ratios by condition",
       subtitle = paste0("Poisson GEE (", main_corstr, "), robust 95% CI"),
       x = "IRR (log scale)", y = NULL) +
  theme_bw()
save_plot(p_forest_A, "A_forest_all_conditions.png", w = 12, h = 6)

# Sensitivity to working correlation structure (PF terms)
p_sens_A <- single_irr_all %>%
  filter(term %in% names(term_labels)) %>%
  mutate(term = factor(term_labels[term], levels = term_labels)) %>%
  ggplot(aes(estimate, model, colour = corstr)) +
  geom_vline(xintercept = 1, linetype = "dashed") +
  geom_pointrange(aes(xmin = conf.low, xmax = conf.high),
                  position = position_dodge(width = 0.6), size = 0.3) +
  facet_wrap(~ term, scales = "free_x") +
  scale_x_log10() +
  labs(title = "Single-group ITSA — sensitivity of IRRs to model choices",
       x = "IRR (log scale)", y = NULL, colour = "Model") +
  theme_bw() + theme(legend.position = "bottom")
save_plot(p_sens_A, "A_sensitivity_corstr.png", w = 12, h = 7)

######################################################################
# Part B. Controlled ITSA — 3 PF conditions with controls
######################################################################

# ---- controlled-models -----------------------------------------------------
# Each practice contributes two series (PF condition, control). The main
# model clusters on the practice-condition series so AR(1) runs along time
# within each series. A sensitivity model clusters on practice
# (exchangeable), so the robust SEs also allow for correlation between a
# practice's PF-condition and control series.

f_ctrl <- as.formula(paste0(
  "y ~ T + X + XT + Z + ZT + ZX + ZXT", season_terms, " + offset(log_pop)"
))

ctrl_irr <- list(); ctrl_trends <- list(); ctrl_diag <- list(); ctrl_check <- list()

for (i in seq_len(nrow(pairs))) {
  pp <- pairs[i, ]
  name <- paste(pp$label, "vs", pp$control_label)
  message("Controlled GEE: ", name)

  d_t <- prep_series(dat, pp$med_var, pp$elig_var)         %>% mutate(Z = 1L)
  d_c <- prep_series(dat, pp$control_med_var, pp$control_elig_var) %>% mutate(Z = 0L)
  d <- bind_rows(d_t, d_c) %>%
    mutate(ZT = Z * T, ZX = Z * X, ZXT = Z * XT,
           series_id = practice_id * 10L + Z) %>%
    arrange(series_id, T)
  ctrl_check[[pp$cond]] <- data_checks(d, name)

  fits <- set_names(map(corstrs, ~ fit_gee(f_ctrl, d, .x, id_col = "series_id")), corstrs)
  fit_prac <- fit_gee(f_ctrl, d %>% arrange(practice_id, Z, T),
                      "exchangeable", id_col = "practice_id")

  ctrl_irr[[pp$cond]] <- bind_rows(
    imap_dfr(fits, ~ tidy_irr(.x, name, .y)),
    tidy_irr(fit_prac, name, "exchangeable (practice clusters)")
  )
  ctrl_diag[[pp$cond]] <- imap_dfr(fits, ~ assess_fit(.x, d, name, .y))

  main <- fits[[main_corstr]]
  if (is.null(main)) next

  # Derived contrasts (IRR scale)
  ctrl_trends[[pp$cond]] <- bind_rows(
    lincom(main, c("T", "ZT"))               %>% mutate(contrast = "Pre-PF trend: PF condition"),
    lincom(main, "T")                        %>% mutate(contrast = "Pre-PF trend: control"),
    lincom(main, c("T", "XT", "ZT", "ZXT"))  %>% mutate(contrast = "Post-PF trend: PF condition"),
    lincom(main, c("T", "XT"))               %>% mutate(contrast = "Post-PF trend: control"),
    lincom(main, c("ZT", "ZXT"))             %>% mutate(contrast = "Post-PF trend ratio: PF condition / control"),
    lincom(main, c("X", "ZX"))               %>% mutate(contrast = "Level change at PF: PF condition"),
    lincom(main, "X")                        %>% mutate(contrast = "Level change at PF: control"),
    lincom(main, "ZX")                       %>% mutate(contrast = "Level change ratio: PF condition / control"),
    lincom(main, "ZXT")                      %>% mutate(contrast = "Trend change ratio: PF condition / control")
  ) %>% mutate(model = name, .before = 1) %>% relocate(contrast, .after = model)

  # Observed vs fitted; controlled counterfactual for the PF condition =
  # own pre-trend + the change seen in the control (ZX = ZXT = 0)
  cf <- d %>% mutate(ZX = 0, ZXT = 0)
  plot_df <- d %>%
    mutate(fitted = predict(main, type = "response"),
           counterfactual = predict(main, newdata = cf, type = "response")) %>%
    group_by(interval_start, Z) %>%
    summarise(across(c(y, fitted, counterfactual), sum), pop = sum(pop), .groups = "drop") %>%
    mutate(across(c(y, fitted, counterfactual), ~ .x / pop * 1000),
           counterfactual = if_else(Z == 1 & interval_start >= PF_start, counterfactual, NA_real_),
           group = if_else(Z == 1, pp$label, paste(pp$control_label, "(control)")))

  p_fit <- ggplot(plot_df, aes(interval_start, colour = group)) +
    geom_point(aes(y = y, shape = group), size = 2) +
    geom_line(aes(y = fitted), linewidth = 1) +
    geom_line(aes(y = counterfactual), linetype = "dashed", linewidth = 0.9, na.rm = TRUE) +
    geom_vline(xintercept = PF_start, linetype = "dashed") +
    geom_vline(xintercept = GP_connect, linetype = "dotted") +
    scale_colour_manual(values = setNames(c("#B2182B", "#2166AC"),
                                          c(pp$label, paste(pp$control_label, "(control)")))) +
    scale_x_date(date_labels = "%Y-%m", date_breaks = "2 months") +
    labs(title = paste("Controlled ITSA:", name),
         subtitle = "Points = observed, solid = GEE fitted, dashed = controlled counterfactual for the PF condition",
         x = NULL, y = paste("Medications per 1,000", offset_type),
         colour = NULL, shape = NULL) +
    theme_bw() + theme(legend.position = "bottom",
                       axis.text.x = element_text(angle = 45, hjust = 1))
  save_plot(p_fit, paste0("B_", pp$cond, "_vs_control_observed_fitted.png"))

  residual_plots(main, d, name, paste0("B_", pp$cond, "_vs_control"))

  if (run_gp_connect_sensitivity) {
    fit_pre <- fit_gee(f_ctrl, d %>% filter(interval_start < GP_connect),
                       main_corstr, id_col = "series_id")
    ctrl_irr[[paste0(pp$cond, "_preGPC")]] <-
      tidy_irr(fit_pre, name, paste0(main_corstr, " (pre-GP Connect)"))
  }
}

ctrl_irr_all    <- bind_rows(ctrl_irr)
ctrl_trends_all <- bind_rows(ctrl_trends)
ctrl_diag_all   <- bind_rows(ctrl_diag)
ctrl_check_all  <- bind_rows(ctrl_check)

write_excel_csv(ctrl_check_all,  file.path(out_dir, "B_data_checks.csv"))
write_excel_csv(ctrl_irr_all,    file.path(out_dir, "B_controlled_irr_all_structures.csv"))
write_excel_csv(ctrl_trends_all, file.path(out_dir, "B_controlled_contrasts.csv"))
write_excel_csv(ctrl_diag_all,   file.path(out_dir, "B_controlled_diagnostics.csv"))

ctrl_term_labels <- c(
  T   = "Control pre-PF trend",
  X   = "Control level change at PF",
  XT  = "Control trend change after PF",
  Z   = "Baseline level ratio (PF cond / control)",
  ZT  = "Pre-trend ratio (PF cond / control)",
  ZX  = "Level change ratio (PF cond / control)",
  ZXT = "Trend change ratio (PF cond / control)"
)

ctrl_main_table <- ctrl_irr_all %>%
  filter(corstr == main_corstr, term %in% names(ctrl_term_labels)) %>%
  transmute(comparison = model, term = ctrl_term_labels[term],
            IRR = round(estimate, 3),
            `95% CI` = sprintf("%.3f–%.3f", conf.low, conf.high),
            p = signif(p.value, 3))
write_excel_csv(ctrl_main_table, file.path(out_dir, "B_controlled_main_table.csv"))
print(ctrl_main_table, n = Inf)
print(ctrl_trends_all %>% select(model, contrast, IRR, IRR_low, IRR_high, p.value), n = Inf)

# Forest plot of the key controlled effects
p_forest_B <- ctrl_irr_all %>%
  filter(term %in% c("ZT", "ZX", "ZXT")) %>%
  mutate(term = factor(ctrl_term_labels[term], levels = ctrl_term_labels[c("ZT", "ZX", "ZXT")])) %>%
  ggplot(aes(estimate, model, colour = corstr)) +
  geom_vline(xintercept = 1, linetype = "dashed", colour = "grey40") +
  geom_pointrange(aes(xmin = conf.low, xmax = conf.high),
                  position = position_dodge(width = 0.6), size = 0.3) +
  facet_wrap(~ term, scales = "free_x") +
  scale_x_log10() +
  labs(title = "Controlled ITSA — PF condition relative to control",
       subtitle = "Robust 95% CI; colours = working correlation / sensitivity model",
       x = "IRR (log scale)", y = NULL, colour = "Model") +
  theme_bw() + theme(legend.position = "bottom")
save_plot(p_forest_B, "B_forest_controlled.png", w = 12, h = 5)

######################################################################
# Part C. Assessment summary
######################################################################

# ---- assessment-summary ----------------------------------------------------
# Best working correlation by QIC for each model, plus overdispersion and
# residual autocorrelation flags.
assessment <- bind_rows(single_diag_all %>% mutate(part = "A. single-group"),
                        ctrl_diag_all   %>% mutate(part = "B. controlled")) %>%
  group_by(part, model) %>%
  mutate(best_QIC = if (all(is.na(QIC))) NA_character_ else corstr[which.min(QIC)]) %>%
  ungroup() %>%
  filter(corstr == main_corstr) %>%
  transmute(part, model, main_corstr = corstr, best_QIC,
            alpha = round(alpha, 3),
            dispersion = round(dispersion_pearson, 2),
            overdispersed = dispersion_pearson > 1.5,
            acf_lag1_monthly = round(acf_lag1_monthly, 2),
            ljung_box_p = signif(ljung_box_p, 3),
            residual_autocorrelation = ljung_box_p < 0.05)

write_excel_csv(assessment, file.path(out_dir, "C_assessment_summary.csv"))
print(assessment, n = Inf, width = Inf)

# Notes for interpretation
# - Poisson GEE with robust (sandwich) SEs gives valid inference under
#   overdispersion; the dispersion column shows how large it is.
# - QIC compares working correlations for the same mean model; the
#   estimates should be similar across structures (see sensitivity plots).
# - A small Ljung-Box p-value means the monthly residuals are still
#   autocorrelated or seasonal: consider adjust_season = TRUE or more
#   harmonics.
# - The pre-GP Connect sensitivity tests whether the post-PF slope is
#   driven by the change in recording from October 2025.

sessionInfo()


