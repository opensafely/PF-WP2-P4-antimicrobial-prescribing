library(tidyverse)

df_input <- read_csv(
  here::here("results_Arnaud", "dummy_dataset_Arnaud.csv.gz"),
  col_types = cols(
    patient_id = col_integer(),
    age = col_double()
  )
)
df_input <- as.data.frame(df_input)    #
plot_imd <- df_input %>%
  filter(factor(imd) != "Missing") %>%
  count(imd) %>%
  ggplot(aes(x = factor(imd), y = n)) +
  geom_col(fill = "#0ea4db") +
  labs(
    title = "Patients by IMD quintile",
    x = "IMD quintile",
    y = "Number of patients"
  ) +
  theme_minimal(base_size = 14)

ggsave(
  plot = plot_imd,
  filename = "output/imd_barplot.png",
  path = here::here(),
  width = 6,
  height = 5,
  dpi = 300
)