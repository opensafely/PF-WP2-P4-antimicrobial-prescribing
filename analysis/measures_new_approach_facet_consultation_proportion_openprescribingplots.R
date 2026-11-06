#--------------------------------------------------------------------------------#
# Proportion of consultations with a medication issued:
# deciles across practices + pooled proportion, GP vs Pharmacy First
# -------------------------------------------------------------------------------#
library(tidyverse)
library(here)
library(scales)

practice_level_data_by_practice_only <- read_csv(
  here("output", "practice_level_data_by_practice_only.csv"),
  show_col_types = FALSE
  ) |>
  mutate(interval_start = as.Date(interval_start))
# Dates 
PF_start   <- as.Date("2024-02-01")
GP_connect <- as.Date("2025-10-01")
# -----------------------------------------------------------------------------#
# Settings                                                                     #
# -----------------------------------------------------------------------------#
min_denominator <- 10    # practice-month needs >= this many consultations
min_practices   <- 10    # deciles shown only if >= this many practices
highlight_prac  <- NULL  # keep NULL for any output to be released

condition_labels <- c(
  uti            = "UTI",
  sinusitis      = "Sinusitis",
  insectbite     = "Insect bites",
  otitismedia    = "Otitis media",
  sorethroat     = "Sore throat",
  shingles       = "Shingles",
  impetigo       = "Impetigo",
  all_conditions = "All conditions"
)

apply_sdc <- function(x) {
  case_when(
    is.na(x) ~ NA_real_,
    x == 0   ~ 0,
    x < 8    ~ NA_real_,
    TRUE     ~ round(x / 5) * 5
  )
}

output_dir <- here("output", "proportion_medication_deciles")
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

# ----------------------------------------------------------------------------- #
# 3. Long format                                                                #
# ----------------------------------------------------------------------------- #
practice_month_all <- practice_level_data_by_practice_only |>
  select(practice, interval_start,
         matches("^(gp|pf)_(medication|consultation)_")) |>
  pivot_longer(
    cols = -c(practice, interval_start),
    names_to = c("setting", ".value", "condition"),
    names_pattern = "^(gp|pf)_(medication|consultation)_(.*)$"
  ) |>
  rename(
    practice_id     = practice,
    month           = interval_start,
    n_medication    = medication,
    n_consultations = consultation
  ) |>
  filter(condition %in% names(condition_labels)) |>
  mutate(
    setting      = recode(setting, gp = "GP", pf = "PF"),
    condition    = factor(unname(condition_labels[condition]),
                          levels = condition_labels),
    n_medication = replace_na(n_medication, 0)
  )

# Practices with enough consultations for a stable proportion
practice_month <- practice_month_all |>
  filter(!is.na(n_consultations), n_consultations >= min_denominator) |>
  mutate(proportion = n_medication / n_consultations)

# -----------------------------------------------------------------------------#
# 4a. Deciles across practices  per setting-condition-month  (unweighted)      #
# -----------------------------------------------------------------------------#

eligible_practice_month <- practice_month |>
  group_by(setting, condition, month) |>
  filter(n() >= min_practices) |>
  ungroup()

if (nrow(eligible_practice_month) == 0) {

  # Return an empty dataframe with the correct column structure
  deciles <- tibble(
    setting = character(),
    condition = factor(character(), levels = unname(condition_labels)),
    month = as.Date(character()),
    percentile = double(),
    value = double(),
    n_practices = integer(),
    type = character()
  )

} else {

  deciles <- eligible_practice_month |>
    group_by(setting, condition, month) |>
    group_modify(~ {

      tibble(
        percentile = seq(10, 90, 10),
        value = as.numeric(
          quantile(
            .x$proportion,
            probs = seq(0.1, 0.9, 0.1),
            na.rm = TRUE,
            names = FALSE
          )
        ),
        n_practices = nrow(.x),
        type = if_else(
          seq(10, 90, 10) == 50,
          "Median",
          "Decile"
        )
      )

    }) |>
    ungroup()
}


# -----------------------------------------------------------------------------
# 4b. Pooled proportion over ALL practices (no denominator filter), with SDC
# -----------------------------------------------------------------------------

pooled <- practice_month_all |>
  group_by(setting, condition, month) |>
  summarise(
    n_medication    = sum(n_medication, na.rm = TRUE),
    n_consultations = sum(n_consultations, na.rm = TRUE),
    .groups = "drop"
  ) |>
  mutate(
    n_medication_sdc    = apply_sdc(n_medication),
    n_consultations_sdc = apply_sdc(n_consultations),

    value = if_else(
      !is.na(n_medication_sdc) &
        !is.na(n_consultations_sdc) &
        n_consultations_sdc > 0,
      n_medication_sdc / n_consultations_sdc,
      NA_real_
    ),

    type = "Pooled (all practices)"
  )



write_csv(deciles, file.path(output_dir, "deciles_med_per_consultation.csv"))
write_csv(
  pooled |> select(setting, condition, month,
                   n_medication_sdc, n_consultations_sdc, value),
  file.path(output_dir, "pooled_med_per_consultation_SDC.csv")
)

# -----------------------------------------------------------------------------
# 5. Plot
# -----------------------------------------------------------------------------
lvl  <- c("Median", "Decile", "Pooled (all practices)", "Selected practice")
cols <- c("Median" = "#3333ff", "Decile" = "#5a5aff",
          "Pooled (all practices)" = "grey25", "Selected practice" = "#ff3b3b")
ltys <- c("Median" = "solid", "Decile" = "22",
          "Pooled (all practices)" = "41", "Selected practice" = "solid")
lwds <- c("Median" = 1.1, "Decile" = 0.4,
          "Pooled (all practices)" = 0.7, "Selected practice" = 1.1)

# Date labels only in the top-left panel
vline_labels <- tibble(
  condition = factor(condition_labels[1], levels = condition_labels),
  setting   = "GP",
  x         = c(PF_start, GP_connect),
  label     = c(" PF launch", " GP Connect")
)

p <- ggplot() +
  geom_vline(xintercept = PF_start,   colour = "grey45", linewidth = 0.5) +
  geom_vline(xintercept = GP_connect, colour = "grey45", linewidth = 0.5,
             linetype = "dashed") +
  geom_line(data = deciles,
            aes(month, value, group = percentile,
                colour = type, linetype = type, linewidth = type)) +
  geom_line(data = pooled,
            aes(month, value, colour = type, linetype = type, linewidth = type))

if (!is.null(highlight_prac)) {
  p <- p + geom_line(
    data = practice_month |>
      filter(practice_id == highlight_prac) |>
      mutate(type = "Selected practice"),
    aes(month, proportion, colour = type, linetype = type, linewidth = type)
  )
}

p <- p +
  geom_text(data = vline_labels, aes(x = x, y = 1, label = label),
            hjust = 0, vjust = 1, size = 2.8, colour = "grey35") +
  facet_grid(condition ~ setting) +
  scale_colour_manual(values = cols, breaks = lvl, name = NULL) +
  scale_linetype_manual(values = ltys, breaks = lvl, name = NULL) +
  scale_linewidth_manual(values = lwds, breaks = lvl, name = NULL) +
  scale_x_date(date_breaks = "2 months", date_labels = "%Y-%m",
               expand = expansion(mult = 0.01)) +
  scale_y_continuous(labels = percent, expand = expansion(mult = c(0, 0.02))) +
  coord_cartesian(ylim = c(0, 1)) +
  labs(
    x = NULL,
    y = "Consultations with medication issued (%)",
    title = "Proportion of consultations with a medication issued, by practice",
    subtitle = paste0(
      "Median and deciles across practices with \u2265", min_denominator,
      " consultations; dashed grey = pooled proportion (all practices)"
    )
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

p

ggsave(file.path(output_dir, "deciles_med_per_consultation.png"), p,
       width = 16, height = 12, dpi = 200, bg = "white")

#SECTION II.By condition
output_dir_gp <- here("output","proportion_medication_deciles","GP_by_condition")
dir.create(output_dir_gp,recursive = TRUE, showWarnings = FALSE)
# -----------------------------------------------------------------------------
# 6. Function: Generate one GP-only graph per condition
# -----------------------------------------------------------------------------

plot_gp_condition <- function(condition_name) {

  # Convert raw condition name to display label
  condition_title <- unname(condition_labels[condition_name])

  # Filter GP data using display label
  deciles_gp <- deciles |>
    filter(
      setting == "GP",
      as.character(condition) == condition_title
    )

  pooled_gp <- pooled |>
    filter(
      setting == "GP",
      as.character(condition) == condition_title
    )

  # Diagnostic
  message(
    "Condition: ", condition_name,
    " | Decile rows: ", nrow(deciles_gp),
    " | Pooled rows: ", nrow(pooled_gp)
  )

  # Skip conditions without data
  if (nrow(deciles_gp) == 0 && nrow(pooled_gp) == 0) {
    message("No GP data available for: ", condition_name)
    return(NULL)
  }

  # Generate graph
  
  p_gp <- ggplot() +

    # Reference dates
    geom_vline(
      xintercept = PF_start,
      colour = "grey45",
      linewidth = 0.5,linetype="dashed"
    ) +

    geom_vline(
      xintercept = GP_connect,
      colour = "grey45",
      linewidth = 0.5,
      linetype = "dashed"
    ) +

    # Deciles and median across practices
    geom_line(
      data = deciles_gp,
      aes(
        x = month,
        y = value,
        group = percentile,
        colour = type,
        linetype = type,
        linewidth = type
      )
    ) +

    # Pooled proportion
    geom_line(
      data = pooled_gp,
      aes(
        x = month,
        y = value,
        colour = type,
        linetype = type,
        linewidth = type
      )
    ) +

    # Reference date labels
    annotate(
      "text",
      x = PF_start,
      y = 0.98,
      label = "PF launch",
      hjust = 0,
      vjust = 1,
      size = 2.8,
      colour = "grey35"
    ) +

    annotate(
      "text",
      x = GP_connect,
      y = 0.90,
      label = "GP Connect",
      hjust = 0,
      vjust = 1,
      size = 2.8,
      colour = "grey35"
    ) +

    scale_colour_manual(
      values = cols,
      breaks = lvl,
      name = NULL
    ) +

    scale_linetype_manual(
      values = ltys,
      breaks = lvl,
      name = NULL
    ) +

    scale_linewidth_manual(
      values = lwds,
      breaks = lvl,
      name = NULL
    ) +

    scale_x_date(
      date_breaks = "2 months",
      date_labels = "%Y-%m",
      expand = expansion(mult = 0.01)
    ) +

    scale_y_continuous(
      labels = percent,
      expand = expansion(mult = c(0, 0.02))
    ) +

    coord_cartesian(ylim = c(0, 1)) +

    labs(
      x = NULL,
      y = "Consultations with medication issued (%)",
      title = paste0(
        "Proportion of GP consultations with medication issued: ",
        condition_title
      ),
      subtitle = paste0(
        "Median and deciles across GP practices with \u2265",
        min_denominator,
        " consultations; pooled proportion across all GP practices"
      )
    ) +

    theme(
      panel.background = element_rect(
        fill = "white",
        colour = NA
      ),
      panel.border = element_rect(
        fill = NA,
        colour = "black",
        linewidth = 0.4
      ),
      panel.grid.major = element_line(
        colour = "grey85",
        linetype = "dashed",
        linewidth = 0.3
      ),
      panel.grid.minor = element_blank(),
      plot.background = element_rect(
        fill = "white",
        colour = NA
      ),
      legend.key = element_rect(
        fill = "white",
        colour = NA
      ),
      legend.position = "bottom",
      axis.text.x = element_text(
        angle = 45,
        hjust = 1
      )
    )

  # Save graph
  filename <- paste0(
    "GP_proportion_medication_",
    condition_name,
    ".png"
  )

  ggsave(
    filename = file.path(output_dir, filename), #the initial one
    plot = p_gp,
    width = 12,
    height = 6,
    dpi = 200,
    bg = "white"
  )

  message("Generated: ", filename)

  return(p_gp)
}

# -----------------------------------------------------------------------------
# 7. Individual GP graphs for all conditions
# -----------------------------------------------------------------------------

gp_condition_plots <- setNames(
  lapply(
    names(condition_labels),
    plot_gp_condition
  ),
  names(condition_labels)
)

