library(dplyr)
library(tidyr)
library(ggplot2)
library(readr)
library(here)

#practice_level_data_by_practice_only <- read_csv("C:/Users/arnau/Downloads/practice_level_data_by_practice_only (2).csv")

practice_level_data_by_practice_only <- read_csv(
  here("output", "practice_level_data_by_practice_only.csv")
  ) %>%
  mutate(interval_start = as.Date(interval_start))
# PF_start and GP Connect dates 
GP_connect <- as.Date("2025-10-01")
PF_start <- as.Date("2022-02-01")

names(practice_level_data_by_practice_only)

# Antibiotic variables: columns 55–74 and 79–82
antibiotic_data <- practice_level_data_by_practice_only %>%
  select(
    practice, interval_start,
    pf_nitrofurantoin_uti:gp_clarithromycin_sorethroat,
    pf_fusidic_acid_impetigo:gp_flucloxacillin_impetigo
  ) %>%
  pivot_longer(
    cols = -c(practice, interval_start),
    names_to = "measure",
    values_to = "count"
  ) %>%
  mutate(
    setting = if_else(grepl("^pf_", measure), "PF", "GP"),
    antibiotic = sub("^(pf|gp)_", "", measure),
    antibiotic = sub("_(uti|sinusitis|insectbite|otitismedia|sorethroat|impetigo)$",
      "", antibiotic),
    antibiotic = gsub("_", " ", antibiotic),
    antibiotic = tools::toTitleCase(antibiotic)
  )

# Aggregate counts across practices, conditions, and months
antibiotic_monthly <- antibiotic_data %>%
  group_by(interval_start, setting, antibiotic) %>%
  summarise(
    count = sum(count, na.rm = TRUE),
    .groups = "drop"
  )

# GP: stacked antibiotics
gp_antibiotics_plot <- antibiotic_monthly %>%
  filter(setting == "GP") %>%
  ggplot(aes(x = interval_start, y = count, fill = antibiotic)) +
  geom_area(position = "stack") +
  scale_x_date(date_labels = "%Y-%m", date_breaks = "1 months") +
  labs(
    title = "A.GP antibiotic prescribing across conditions",
    x = "Month",
    y = "Number of prescriptions",
    fill = " "
  ) +
  theme_bw() +
  guides(fill = guide_legend(nrow = 1, title.position = "left")) +
  theme(legend.position = "bottom",
    axis.text.x = element_text(angle = 45, hjust = 1),
    legend.text = element_text(size = 8),
    legend.key.size = unit(0.4, "cm"))
  
  #    theme(
  #    axis.text.x = element_text(angle = 45, hjust = 1),
  #    legend.position = "bottom"
  #      )

# Pharmacy First: stacked antibiotics
pf_antibiotics_plot <- antibiotic_monthly %>%
  filter(setting == "PF") %>%
  ggplot(aes(x = interval_start, y = count, fill = antibiotic)) +
  geom_area(position = "stack") +
  scale_x_date(date_labels = "%Y-%m", date_breaks = "1 months") +
  labs(
    title = "B.PF antibiotic prescribing across conditions",
    x = "Month",
    y = "Number of prescriptions",
    fill = ""
  ) +
  theme_bw() +
  guides(fill = guide_legend(nrow = 1, title.position = "left")) +
  theme(legend.position = "bottom",
    axis.text.x = element_text(angle = 45, hjust = 1),
    legend.text = element_text(size = 8),
    legend.key.size = unit(0.4, "cm"))

  #theme(
  #  axis.text.x = element_text(angle = 45, hjust = 1),
  #  legend.position = "bottom"
  #)

# Display the two separate graphs
print(gp_antibiotics_plot)
print(pf_antibiotics_plot)

ggsave(
  filename = "output/results_7_medications_gp.png",
  plot = gp_antibiotics_plot,
  path = here::here(),
  width = 10,
  height = 6,
  dpi = 300
)
ggsave(
  filename = "output/results_7_medications_pf.png",
  plot = pf_antibiotics_plot,
  path = here::here(),
  width = 10,
  height = 6,
  dpi = 300
)