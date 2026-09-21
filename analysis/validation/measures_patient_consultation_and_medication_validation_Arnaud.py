from ehrql import case, create_measures, months, when
#from analysis.dataset_definition_patients_measures import dataset
from analysis.dataset_definition_patients_measures_Arnaud import dataset
# opensafely exec ehrql:v1 generate-measures analysis/measures_patient.py --output output/measures_patient.csv

measures = create_measures()
measures.configure_disclosure_control(enabled=False)
measures.define_defaults(
    intervals=months(2).starting_on("2025-10-01"),
    # intervals=months(2).starting_on("2024-02-01")
)

measure_base_population = (
    dataset.alive
    & dataset.registered_start
    & dataset.registered_index
    & (dataset.age <= 120)
)

'''
Checks:
1. PF consultation count
- pf_consultation_general_total should capture all consultations with PF service codes.
- pf_consultation_general_butno_condition_total should be smaller than pf_consultation_general_total.
- pf_consultation_condition_sum_total should be compared with pf_consultation_general_total - pf_consultation_general_butno_condition_total.
- - If condition sum is larger, this suggests some PF consultations may be assigned to more than one condition.
2. PF consultation count vs same-day consultation count ('episode')
- For each condition, pf_date_<condition> should be less than or equal to pf_consultation_<condition>.
3. GP consultation vs episode
- For each condition, gp_date_<condition> should be less than or equal to gp_consultation_<condition>.
4. PF consultation count vs GP consultation count 
- compare by condition
- change by month
5. A&E variables
- ae_<condition>_primary_count should generally be low
- ae_<condition>_non_primary_flag may be higher than primary counts, but very high values may suggest broad diagnosis matching.
6. Among patients with PF consultations for a given condition, all of them should meet the corresponding eligibility criteria.
7. Medication
- patient_has_medication_<condition> should be less than or equal to medication_count_<condition>.
- medication_<condition>_among_pf_consultation: proportion of patients with >=1 PF consultation for the
  condition who also have >=1 medication event for that condition in the same interval.
  Interpret with caution: medicines supplied by the pharmacy under PF may not appear in the GP prescribing record.
- medication_<condition>_among_gp_consultation: same, for patients with >=1 GP consultation for the condition
  (comparison group).
- pf_medication_<condition> / gp_medication_<condition>: number of medication events for the condition among
  patients with >=1 PF / GP consultation for that condition in the same interval.
  Each should be less than or equal to medication_count_<condition>. A patient with both a PF and a GP
  consultation is counted in both, so pf_medication + gp_medication can exceed medication_count.
  These are same-interval co-occurrence measures, not proof that the medication came from that consultation.
'''

measures.define_measure(
    name="pf_consultation_general_total",
    numerator=dataset.pf_consultation_general,
    denominator=measure_base_population,
)
measures.define_measure(
    name="pf_consultation_general_butno_condition_total",
    numerator=dataset.pf_consultation_general_butno_condition,
    denominator=measure_base_population,
)
pf_condition_consultation_sum = (
    dataset.numerator_pf_consultation_uti
    + dataset.numerator_pf_consultation_sinusitis
    + dataset.numerator_pf_consultation_insectbite
    + dataset.numerator_pf_consultation_otitismedia
    + dataset.numerator_pf_consultation_sorethroat
    + dataset.numerator_pf_consultation_shingles
    + dataset.numerator_pf_consultation_impetigo
)
measures.define_measure(
    name="pf_consultation_condition_sum_total",
    numerator=pf_condition_consultation_sum,
    denominator=measure_base_population,
)

pf_conditions = [
    "uti",
    "sinusitis",
    "insectbite",
    "otitismedia",
    "sorethroat",
    "shingles",
    "impetigo",
]

for condition in pf_conditions:

    # check numerator only
    measures.define_measure(
        name=f"pf_consultation_{condition}",
        numerator=getattr(dataset, f"numerator_pf_consultation_{condition}"),
        denominator=measure_base_population,
    )

    # check numerator only
    measures.define_measure(
        name=f"pf_date_{condition}",
        numerator=getattr(dataset, f"numerator_pf_date_{condition}"),
        denominator=measure_base_population,
    )

    # check numerator only
    measures.define_measure(
        name=f"gp_consultation_{condition}",
        numerator=getattr(dataset, f"numerator_gp_consultation_{condition}"),
        denominator=measure_base_population,
    )

    # check numerator only
    measures.define_measure(
        name=f"gp_date_{condition}",
        numerator=getattr(dataset, f"numerator_gp_date_{condition}"),
        denominator=measure_base_population,
    )

    # check numerator only
    measures.define_measure(
        name=f"ae_{condition}_primary_count",
        numerator=getattr(dataset, f"ae_{condition}_primary_count"),
        denominator=measure_base_population,
    )

    # proportion of patients with ≥1 non-primary A&E diagnosis
    measures.define_measure(
        name=f"patient_has_non_primary_ae_{condition}",
        numerator=getattr(dataset, f"has_ae_{condition}_non_primary"),
        denominator=measure_base_population,
    )

# check numerator only
measures.define_measure(
    name="ae_attendance_total",
    numerator=dataset.ae_attendance_count,
    denominator=measure_base_population,
)

pf_condition_map = {
    "uti": "uuti",
    "sinusitis": "sinusitis",
    "insectbite": "insect_bites",
    "otitismedia": "otitis_media",
    "sorethroat": "sore_throat",
    "shingles": "shingles",
    "impetigo": "impetigo",
}

for condition, eligibility_name in pf_condition_map.items():

    # Among patients with ≥1 PF consultation for a given condition, 
    # the proportion that meets the corresponding PF eligibility criteria.
    measures.define_measure(
        name=f"pf_{condition}_eligible_among_pf_consultation",
        numerator=getattr(dataset, f"include_patient_{eligibility_name}"),
        denominator=(
            getattr(dataset, f"numerator_pf_consultation_{condition}") > 0
        ) & measure_base_population,
    )

########################################################
# Medication measures (no A&E)
# Requires analysis/medication_variables.py to have been
# applied to `dataset`: add_medication_variables(dataset)
########################################################

for condition in pf_conditions:

    # number of medication events for the condition (check numerator only)
    measures.define_measure(
        name=f"medication_count_{condition}",
        numerator=getattr(dataset, f"numerator_medication_{condition}"),
        denominator=measure_base_population,
    )

    # number of patients with >=1 medication event for the condition
    measures.define_measure(
        name=f"patient_has_medication_{condition}",
        numerator=getattr(dataset, f"has_medication_{condition}"),
        denominator=measure_base_population,
    )

    # Among patients with >=1 PF consultation for the condition,
    # the proportion with >=1 medication event for that condition.
    pf_condition_patients = (
        getattr(dataset, f"numerator_pf_consultation_{condition}") > 0
    ) & measure_base_population
    measures.define_measure(
        name=f"medication_{condition}_among_pf_consultation",
        numerator=getattr(dataset, f"has_medication_{condition}") & pf_condition_patients,
        denominator=pf_condition_patients,
    )

    # Same, for patients with >=1 GP consultation for the condition (comparison)
    gp_condition_patients = (
        getattr(dataset, f"numerator_gp_consultation_{condition}") > 0
    ) & measure_base_population
    measures.define_measure(
        name=f"medication_{condition}_among_gp_consultation",
        numerator=getattr(dataset, f"has_medication_{condition}") & gp_condition_patients,
        denominator=gp_condition_patients,
    )

    # PF medication / GP medication (same style as pf_consultation / gp_consultation):
    # number of medication events for the condition among patients who had >=1 PF
    # (or >=1 GP) consultation for that condition in the same interval.
    # A patient with both a PF and a GP consultation is counted in both measures.
    medication_events = getattr(dataset, f"numerator_medication_{condition}")

    # check numerator only
    measures.define_measure(
        name=f"pf_medication_{condition}",
        numerator=case(
            when(getattr(dataset, f"numerator_pf_consultation_{condition}") > 0).then(medication_events),
            otherwise=0,
        ),
        denominator=measure_base_population,
    )

    # check numerator only
    measures.define_measure(
        name=f"gp_medication_{condition}",
        numerator=case(
            when(getattr(dataset, f"numerator_gp_consultation_{condition}") > 0).then(medication_events),
            otherwise=0,
        ),
        denominator=measure_base_population,
    )

# patients with a medication event for any of the 7 conditions
measures.define_measure(
    name="patient_has_medication_any_condition",
    numerator=dataset.has_medication_any,
    denominator=measure_base_population,
)