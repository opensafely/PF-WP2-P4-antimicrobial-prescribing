from ehrql import case, create_measures, months, when
#from analysis.dataset_definition_patients_measures import dataset
from analysis.dataset_definition_patients_measures_Arnaud import dataset
# opensafely exec ehrql:v1 generate-measures analysis/measures_patient.py --output output/measures_patient.csv

measures = create_measures()
measures.configure_disclosure_control(enabled=False)
measures.define_defaults(
    intervals=months(7).starting_on("2025-07-01"),
    # intervals=months(4).starting_on("2024-07-01")
)

measure_base_population = (
    dataset.alive
    & dataset.registered_start
    & dataset.registered_index
    & (dataset.age <= 120)
)

#------------Protocole_4------------------------------------------------
#  I.Measures for each PF condition The denominator can change over time
#-----------------------------------------------------------------------
measures.define_measure(
    name="pf_medication_uti",
    numerator= dataset.numerator_pf_medication_uti,
    denominator=measure_base_population & dataset.include_patient_uuti
    )
measures.define_measure(
    name="gp_medication_uti",
    numerator= dataset.numerator_gp_medication_uti,
    denominator=measure_base_population & dataset.include_patient_uuti)
# Sinusitis
measures.define_measure(
    name="pf_medication_sinusitis",
    numerator=dataset.numerator_pf_medication_sinusitis,
    denominator=measure_base_population & dataset.include_patient_sinusitis
    )

measures.define_measure(
    name="gp_medication_sinusitis",
    numerator=dataset.numerator_gp_medication_sinusitis,
    denominator=measure_base_population & dataset.include_patient_sinusitis
    )
# Insect bites
measures.define_measure(
    name="pf_medication_insectbite",
    numerator=dataset.numerator_pf_medication_insectbite,
    denominator=measure_base_population & dataset.include_patient_insect_bites
    )

measures.define_measure(
    name="gp_medication_insectbite",
    numerator=dataset.numerator_gp_medication_insectbite,
    denominator=measure_base_population & dataset.include_patient_insect_bites
    )

# Otitis media
measures.define_measure(
    name="pf_medication_otitismedia",
    numerator=dataset.numerator_pf_medication_otitismedia,
    denominator=measure_base_population & dataset.include_patient_otitis_media
    )

measures.define_measure(
    name="gp_medication_otitismedia",
    numerator=dataset.numerator_gp_medication_otitismedia,
    denominator=measure_base_population & dataset.include_patient_otitis_media
    )

# Sore throat
measures.define_measure(
    name="pf_medication_sorethroat",
    numerator=dataset.numerator_pf_medication_sorethroat,
    denominator=measure_base_population & dataset.include_patient_sore_throat
    )

measures.define_measure(
    name="gp_medication_sorethroat",
    numerator=dataset.numerator_gp_medication_sorethroat,
    denominator=measure_base_population & dataset.include_patient_sore_throat
    )
# Shingles
measures.define_measure(
    name="pf_medication_shingles",
    numerator=dataset.numerator_pf_medication_shingles,
    denominator=measure_base_population & dataset.include_patient_shingles
    )

measures.define_measure(
    name="gp_medication_shingles",
    numerator=dataset.numerator_gp_medication_shingles,
    denominator=measure_base_population & dataset.include_patient_shingles
    )
# Impetigo
measures.define_measure(
    name="pf_medication_impetigo",
    numerator=dataset.numerator_pf_medication_impetigo,
    denominator=measure_base_population & dataset.include_patient_impetigo
     )

measures.define_measure(
    name="gp_medication_impetigo",
    numerator=dataset.numerator_gp_medication_impetigo,
    denominator=measure_base_population & dataset.include_patient_impetigo
    )

#.II.Measures for the all pf conditions by setting (GP,PF)
#all_conditions
measures.define_measure(
    name="pf_medication_all_conditions",
    numerator= dataset.numerator_pf_medication_all_conditions,
    denominator= measure_base_population & dataset.include_patient_overall_eligible
    )
#
measures.define_measure(
    name="gp_medication_all_conditions",
    numerator= dataset.numerator_gp_medication_all_conditions,
    denominator= measure_base_population & dataset.include_patient_overall_eligible
    )