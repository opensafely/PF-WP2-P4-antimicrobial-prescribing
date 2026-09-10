from ehrql import create_measures, months, years
from analysis.dataset_definition_patients_measures_Arnaud import dataset  # measures arnaud instead measures 
#from analysis.dataset_definition_patients_Arnaud import dataset  # as i haven't yet called all variables at patients level in patients measures.py, i will be calling it dataset ( inorder to use some variables. normally there are quite similar)
# opensafely exec ehrql:v1 generate-measures analysis/practice_variables/measures_practice_Arnaud.py --output output/measures_practice.csv

from ehrql import claim_permissions
claim_permissions("appointments")

# Create measures object
measures = create_measures()
measures.configure_disclosure_control(enabled=False)
measures.define_defaults(
    intervals=months(7).starting_on("2025-07-01"), # intervals=months(2).starting_on("2025-10-01") Here we may be able to see both GP and PF data in GP records.
    #intervals=years(48).starting_on("2024-02-01")
)

measure_base_population = (
    dataset.alive
    & dataset.registered_start
    & dataset.registered_index
    & (dataset.age <= 120)
)

pf_eligible_population = (
    dataset.include_patient_overall_eligible
    & measure_base_population
)

"""
group = {
    "practice": dataset.practice,
    "stp": dataset.stp,
    "region": dataset.region,
}

"""
#Practice level measures

#"""

group = {
    "practice": dataset.practice
}
#"""
# appointments scheduled 
measures.define_measure(
    name="appointments_scheduled",
    numerator=dataset.appointment_scheduled,
    denominator=measure_base_population,
    group_by=group,
)
# appointments seen
measures.define_measure(
    name="appointments_seen",
    numerator=dataset.appointment_seen,
    denominator=measure_base_population,
    group_by=group,
)
#------------P4.Consultations---------------------------------------------------------
#measures.define_measure(
  #  name="gp_consultation_general",
   # numerator=dataset.gp_consultation_general,
    #denominator=pf_eligible_population, #or gp eligible pop?
    #group_by=group,
#)

# uti 
measures.define_measure(
    name="pf_consultation_uti",
    numerator=dataset.numerator_pf_consultation_uti,
    denominator=measure_base_population & dataset.include_patient_uuti,
    group_by=group,
)
measures.define_measure(
    name="gp_consultation_uti",
    numerator=dataset.numerator_gp_consultation_uti,
    denominator=measure_base_population & dataset.include_patient_uuti,
    group_by=group,
)

#"""
# Sinusitis
measures.define_measure(
    name="pf_consultation_sinusitis",
    numerator=dataset.numerator_pf_consultation_sinusitis,
    denominator=measure_base_population & dataset.include_patient_sinusitis,
    group_by=group,
)
measures.define_measure(
    name="gp_consultation_sinusitis",
    numerator=dataset.numerator_gp_consultation_sinusitis,
    denominator=measure_base_population & dataset.include_patient_sinusitis,
    group_by=group,
)
# Insect bites
measures.define_measure(
    name="pf_consultation_insectbite",
    numerator=dataset.numerator_pf_consultation_insectbite,
    denominator=measure_base_population & dataset.include_patient_insect_bites,
    group_by=group,
)
measures.define_measure(
    name="gp_consultation_insectbite",
    numerator=dataset.numerator_gp_consultation_insectbite,
    denominator=measure_base_population & dataset.include_patient_insect_bites,
    group_by=group,
)
# Otitis media
measures.define_measure(
    name="pf_consultation_otitismedia",
    numerator=dataset.numerator_pf_consultation_otitismedia,
    denominator=measure_base_population & dataset.include_patient_otitis_media,
    group_by=group,
)

measures.define_measure(
    name="gp_consultation_otitismedia",
    numerator=dataset.numerator_gp_consultation_otitismedia,
    denominator=measure_base_population & dataset.include_patient_otitis_media,
    group_by=group,
)
# Sore throat
measures.define_measure(
    name="pf_consultation_sorethroat",
    numerator=dataset.numerator_pf_consultation_sorethroat,
    denominator=measure_base_population & dataset.include_patient_sore_throat,
    group_by=group,
)

measures.define_measure(
    name="gp_consultation_sorethroat",
    numerator=dataset.numerator_gp_consultation_sorethroat,
    denominator=measure_base_population & dataset.include_patient_sore_throat,
    group_by=group,
)
# Shingles
measures.define_measure(
    name="pf_consultation_shingles",
    numerator=dataset.numerator_pf_consultation_shingles,
    denominator=measure_base_population & dataset.include_patient_shingles,
    group_by=group,
)
measures.define_measure(
    name="gp_consultation_shingles",
    numerator=dataset.numerator_gp_consultation_shingles,
    denominator=measure_base_population & dataset.include_patient_shingles,
    group_by=group,
)
# Impetigo
measures.define_measure(
    name="pf_consultation_impetigo",
    numerator=dataset.numerator_pf_consultation_impetigo,
    denominator=measure_base_population & dataset.include_patient_impetigo,
    group_by=group,
)

measures.define_measure(
    name="gp_consultation_impetigo",
    numerator=dataset.numerator_gp_consultation_impetigo,
    denominator=measure_base_population & dataset.include_patient_impetigo,
    group_by=group,
)

# All Pharmacy First conditions
measures.define_measure(
    name="pf_consultation_all_conditions",
    numerator=dataset.numerator_pf_consultation_all_conditions,
    denominator=measure_base_population & dataset.include_patient_overall_eligible,
    group_by=group,
)
measures.define_measure(
    name="gp_consultation_all_conditions",
    numerator=dataset.numerator_gp_consultation_all_conditions,
    denominator=measure_base_population & dataset.include_patient_overall_eligible,
    group_by=group,
)

#Controls conditions (gp)
# Acute bronchitis
measures.define_measure(
    name="gp_consultation_acutebronchitis_control",
    numerator=dataset.numerator_gp_consultation_acutebronchitis_control,
    denominator=measure_base_population & dataset.include_patient_sore_throat,
    group_by=group,
)
# Allergic conjunctivitis
measures.define_measure(
    name="gp_consultation_conjunctivitisallergic_control",
    numerator=dataset.numerator_gp_consultation_conjunctivitisallergic_control,
    denominator=measure_base_population & dataset.include_patient_insect_bites,
    group_by=group,
)
#"""
# Vulvovaginal candidiasis
measures.define_measure(
    name="gp_consultation_vulvovaginalcandidiasis_control",
    numerator=dataset.numerator_gp_consultation_vulvovaginalcandidiasis_control,
    denominator=measure_base_population & dataset.include_patient_uuti,
    group_by=group,
)

#------------P4.Medications-------------------------------------------------------------------
#UTI 
measures.define_measure(
    name="pf_medication_uti",
    numerator=dataset.numerator_pf_medication_uti,
    denominator=measure_base_population & dataset.include_patient_uuti,
    group_by=group,
)

measures.define_measure(
    name="gp_medication_uti",
    numerator=dataset.numerator_gp_medication_uti,
    denominator=measure_base_population & dataset.include_patient_uuti,
    group_by=group,
)

#"""
# Sinusitis
measures.define_measure(
    name="pf_medication_sinusitis",
    numerator=dataset.numerator_pf_medication_sinusitis,
    denominator=measure_base_population & dataset.include_patient_sinusitis,
    group_by=group,
)

measures.define_measure(
    name="gp_medication_sinusitis",
    numerator=dataset.numerator_gp_medication_sinusitis,
    denominator=measure_base_population & dataset.include_patient_sinusitis,
    group_by=group,
)
# Infected insect bites
measures.define_measure(
    name="pf_medication_insectbite",
    numerator=dataset.numerator_pf_medication_insectbite,
    denominator=measure_base_population & dataset.include_patient_insect_bites,
    group_by=group,
)

measures.define_measure(
    name="gp_medication_insectbite",
    numerator=dataset.numerator_gp_medication_insectbite,
    denominator=measure_base_population & dataset.include_patient_insect_bites,
    group_by=group,
)
# Otitis media
measures.define_measure(
    name="pf_medication_otitismedia",
    numerator=dataset.numerator_pf_medication_otitismedia,
    denominator=measure_base_population & dataset.include_patient_otitis_media,
    group_by=group,
)
measures.define_measure(
    name="gp_medication_otitismedia",
    numerator=dataset.numerator_gp_medication_otitismedia,
    denominator=measure_base_population & dataset.include_patient_otitis_media,
    group_by=group,
)
# Sore throat
measures.define_measure(
    name="pf_medication_sorethroat",
    numerator=dataset.numerator_pf_medication_sorethroat,
    denominator=measure_base_population & dataset.include_patient_sore_throat,
    group_by=group,
)
measures.define_measure(
    name="gp_medication_sorethroat",
    numerator=dataset.numerator_gp_medication_sorethroat,
    denominator=measure_base_population & dataset.include_patient_sore_throat,
    group_by=group,
)
# Shingles
measures.define_measure(
    name="pf_medication_shingles",
    numerator=dataset.numerator_pf_medication_shingles,
    denominator=measure_base_population & dataset.include_patient_shingles,
    group_by=group,
)
measures.define_measure(
    name="gp_medication_shingles",
    numerator=dataset.numerator_gp_medication_shingles,
    denominator=measure_base_population & dataset.include_patient_shingles,
    group_by=group,
)
# Impetigo
measures.define_measure(
    name="pf_medication_impetigo",
    numerator=dataset.numerator_pf_medication_impetigo,
    denominator=measure_base_population & dataset.include_patient_impetigo,
    group_by=group,
)
measures.define_measure(
    name="gp_medication_impetigo",
    numerator=dataset.numerator_gp_medication_impetigo,
    denominator=measure_base_population & dataset.include_patient_impetigo,
    group_by=group,
)
#
# All Pharmacy First conditions
measures.define_measure(
    name="pf_medication_all_conditions",
    numerator=dataset.numerator_pf_medication_all_conditions,
    denominator=measure_base_population & dataset.include_patient_overall_eligible,
    group_by=group,
)
measures.define_measure(
    name="gp_medication_all_conditions",
    numerator=dataset.numerator_gp_medication_all_conditions,
    denominator=measure_base_population & dataset.include_patient_overall_eligible,
    group_by=group,
)
#Controls conditions (gp)
# Acute bronchitis
measures.define_measure(
    name="gp_medication_acutebronchitis_control",
    numerator=dataset.numerator_gp_medication_acutebronchitis_control,
    denominator=measure_base_population & dataset.include_patient_sore_throat,
    group_by=group,
)
# Allergic conjunctivitis
measures.define_measure(
    name="gp_medication_conjunctivitisallergic_control",
    numerator=dataset.numerator_gp_medication_conjunctivitisallergic_control,
    denominator=measure_base_population & dataset.include_patient_insect_bites,
    group_by=group,
)
#"""
# Vulvovaginal candidiasis
measures.define_measure(
    name="gp_medication_vulvovaginalcandidiasis_control",
    numerator=dataset.numerator_gp_medication_vulvovaginalcandidiasis_control,
    denominator=measure_base_population & dataset.include_patient_uuti,
    group_by=group,
)
# Specific medication



