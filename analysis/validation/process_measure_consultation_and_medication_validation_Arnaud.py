import pandas as pd
import matplotlib.pyplot as plt

input_file = "output/patient_measures_consultation_and_medication_validation.csv"
output_file = "output/patient_measures_consultation_and_medication_validation_ordered.csv"

df = pd.read_csv(input_file)

########################################################
# Conditions
########################################################

conditions = [
    "uti",
    "sinusitis",
    "insectbite",
    "otitismedia",
    "sorethroat",
    "shingles",
    "impetigo",
]

########################################################
# Define measure order
########################################################

measure_order = [

    # PF overall totals
    "pf_consultation_general_total",
    "pf_consultation_general_butno_condition_total",
    "pf_consultation_condition_sum_total",

    # PF consultation counts
    "pf_consultation_uti",
    "pf_consultation_sinusitis",
    "pf_consultation_insectbite",
    "pf_consultation_otitismedia",
    "pf_consultation_sorethroat",
    "pf_consultation_shingles",
    "pf_consultation_impetigo",

    # PF dates (before it was PF episodes)
    "pf_date_uti",
    "pf_date_sinusitis",
    "pf_date_insectbite",
    "pf_date_otitismedia",
    "pf_date_sorethroat",
    "pf_date_shingles",
    "pf_date_impetigo",

    # GP consultations
    "gp_consultation_uti",
    "gp_consultation_sinusitis",
    "gp_consultation_insectbite",
    "gp_consultation_otitismedia",
    "gp_consultation_sorethroat",
    "gp_consultation_shingles",
    "gp_consultation_impetigo",

    # GP dates ( before it was GP episodes)
    "gp_date_uti",
    "gp_date_sinusitis",
    "gp_date_insectbite",
    "gp_date_otitismedia",
    "gp_date_sorethroat",
    "gp_date_shingles",
    "gp_date_impetigo",

    # PF medication (medication events among patients with a PF consultation for the condition)
    "pf_medication_uti",
    "pf_medication_sinusitis",
    "pf_medication_insectbite",
    "pf_medication_otitismedia",
    "pf_medication_sorethroat",
    "pf_medication_shingles",
    "pf_medication_impetigo",

    # GP medication (medication events among patients with a GP consultation for the condition)
    "gp_medication_uti",
    "gp_medication_sinusitis",
    "gp_medication_insectbite",
    "gp_medication_otitismedia",
    "gp_medication_sorethroat",
    "gp_medication_shingles",
    "gp_medication_impetigo",

    # Medication: number of medication events (all patients)
    "medication_count_uti",
    "medication_count_sinusitis",
    "medication_count_insectbite",
    "medication_count_otitismedia",
    "medication_count_sorethroat",
    "medication_count_shingles",
    "medication_count_impetigo",

    # Medication: number of patients with >=1 medication event
    "patient_has_medication_uti",
    "patient_has_medication_sinusitis",
    "patient_has_medication_insectbite",
    "patient_has_medication_otitismedia",
    "patient_has_medication_sorethroat",
    "patient_has_medication_shingles",
    "patient_has_medication_impetigo",
    "patient_has_medication_any_condition",

    # A&E primary
    "ae_attendance_total",
    "ae_uti_primary_count",
    "ae_sinusitis_primary_count",
    "ae_insectbite_primary_count",
    "ae_otitismedia_primary_count",
    "ae_sorethroat_primary_count",
    "ae_shingles_primary_count",
    "ae_impetigo_primary_count",

    # A&E non-primary
    "patient_has_non_primary_ae_uti",
    "patient_has_non_primary_ae_sinusitis",
    "patient_has_non_primary_ae_insectbite",
    "patient_has_non_primary_ae_otitismedia",
    "patient_has_non_primary_ae_sorethroat",
    "patient_has_non_primary_ae_shingles",
    "patient_has_non_primary_ae_impetigo",

    # Eligibility among PF consultation
    "pf_uti_eligible_among_pf_consultation",
    "pf_sinusitis_eligible_among_pf_consultation",
    "pf_insectbite_eligible_among_pf_consultation",
    "pf_otitismedia_eligible_among_pf_consultation",
    "pf_sorethroat_eligible_among_pf_consultation",
    "pf_shingles_eligible_among_pf_consultation",
    "pf_impetigo_eligible_among_pf_consultation",

    # Medication among PF consultation
    "medication_uti_among_pf_consultation",
    "medication_sinusitis_among_pf_consultation",
    "medication_insectbite_among_pf_consultation",
    "medication_otitismedia_among_pf_consultation",
    "medication_sorethroat_among_pf_consultation",
    "medication_shingles_among_pf_consultation",
    "medication_impetigo_among_pf_consultation",

    # Medication among GP consultation
    "medication_uti_among_gp_consultation",
    "medication_sinusitis_among_gp_consultation",
    "medication_insectbite_among_gp_consultation",
    "medication_otitismedia_among_gp_consultation",
    "medication_sorethroat_among_gp_consultation",
    "medication_shingles_among_gp_consultation",
    "medication_impetigo_among_gp_consultation",
]

########################################################
# Apply ordering
########################################################

df["measure_order"] = df["measure"].apply(
    lambda x: measure_order.index(x) if x in measure_order else 999
)

df = df.sort_values(
    by=[
        "interval_start",
        "measure_order",
        "measure",
    ]
)

########################################################
# Save ordered output
########################################################
df = df.drop(columns=["measure_order"])
df.to_csv(output_file, index=False)

########################################################
# Condition-level validation summary table
########################################################

summary_rows = []
months = sorted(df["interval_start"].unique())

for month in months:
    month_df = df[df["interval_start"] == month]

    def get_value(measure_name, column="numerator"):
        result = month_df.loc[month_df["measure"] == measure_name, column]
        if len(result) == 0:
            return None
        return result.iloc[0]

    for condition in conditions:
        eligibility_measure = f"pf_{condition}_eligible_among_pf_consultation"
        med_pf_measure = f"medication_{condition}_among_pf_consultation"
        med_gp_measure = f"medication_{condition}_among_gp_consultation"

        summary_rows.append({
            "month": month,
            "condition": condition,

            "pf_consultation": get_value(f"pf_consultation_{condition}"),
            "pf_date": get_value(f"pf_date_{condition}"),
            "gp_consultation": get_value(f"gp_consultation_{condition}"),
            "gp_date": get_value(f"gp_date_{condition}"),
            "ae_primary_count": get_value(f"ae_{condition}_primary_count"),
            "patient_has_non_primary_ae": get_value(f"patient_has_non_primary_ae_{condition}"),

            # Medication
            "pf_medication": get_value(f"pf_medication_{condition}"),
            "gp_medication": get_value(f"gp_medication_{condition}"),
            "medication_count": get_value(f"medication_count_{condition}"),
            "patient_has_medication": get_value(f"patient_has_medication_{condition}"),

            # Keep numerator/denominator for disclosure control of the ratios
            "pf_consultation_eligibility_ratio": get_value(eligibility_measure, column="ratio"),  # Proportion of PF consultation patients who were eligible
            "pf_consultation_eligibility_numerator": get_value(eligibility_measure, column="numerator"),  # Patients eligible for this PF condition
            "pf_consultation_eligibility_denominator": get_value(eligibility_measure, column="denominator"),  # Patients with at least one PF consultation for this condition

            "medication_among_pf_ratio": get_value(med_pf_measure, column="ratio"),  # Proportion of PF consultation patients with a medication for this condition
            "medication_among_pf_numerator": get_value(med_pf_measure, column="numerator"),
            "medication_among_pf_denominator": get_value(med_pf_measure, column="denominator"),

            "medication_among_gp_ratio": get_value(med_gp_measure, column="ratio"),  # Same, GP consultation patients (comparison)
            "medication_among_gp_numerator": get_value(med_gp_measure, column="numerator"),
            "medication_among_gp_denominator": get_value(med_gp_measure, column="denominator"),
        })

summary_df = pd.DataFrame(summary_rows)

summary_df.to_csv(
    "output/patient_measures_consultation_and_medication_validation_summary.csv",
    index=False,
)

########################################################
# Plot helper: counts by condition and month
########################################################

def plot_by_condition(prefix, ylabel, filename, exclude=()):
    plot_df = df[df["measure"].str.startswith(prefix)].copy()
    plot_df = plot_df[~plot_df["measure"].isin(exclude)]

    # simplify condition names
    plot_df["condition"] = plot_df["measure"].str.replace(prefix, "", regex=False)

    # use month label
    plot_df["month"] = pd.to_datetime(plot_df["interval_start"]).dt.strftime("%Y-%m")

    # pivot for plotting
    plot_pivot = plot_df.pivot(index="condition", columns="month", values="numerator")

    ax = plot_pivot.plot(kind="bar", figsize=(10, 6))
    ax.grid(axis="y", linestyle="--", alpha=0.7)
    ax.set_ylabel(ylabel)
    ax.set_xlabel("Condition")
    ax.set_title(f"{ylabel} by condition and month")

    plt.xticks(rotation=45)
    plt.tight_layout()
    plt.savefig(filename, dpi=300)
    plt.close()

########################################################
# PF consultation counts by condition
########################################################

plot_by_condition(
    prefix="pf_consultation_",
    ylabel="PF consultation count",
    filename="output/patient_measures_pf_consultations_by_condition.png",
    exclude=[
        # exclude overall totals
        "pf_consultation_general_total",
        "pf_consultation_general_butno_condition_total",
        "pf_consultation_condition_sum_total",
    ],
)

########################################################
# GP consultation counts by condition
########################################################

plot_by_condition(
    prefix="gp_consultation_",
    ylabel="GP consultation count",
    filename="output/patient_measures_gp_consultation_by_condition.png",
)

########################################################
# PF medication counts by condition
########################################################

plot_by_condition(
    prefix="pf_medication_",
    ylabel="PF medication count",
    filename="output/patient_measures_pf_medication_by_condition.png",
)

########################################################
# GP medication counts by condition
########################################################

plot_by_condition(
    prefix="gp_medication_",
    ylabel="GP medication count",
    filename="output/patient_measures_gp_medication_by_condition.png",
)

########################################################
# Medication counts by condition (all patients)
########################################################

plot_by_condition(
    prefix="medication_count_",
    ylabel="Medication count",
    filename="output/patient_measures_medication_by_condition.png",
)
