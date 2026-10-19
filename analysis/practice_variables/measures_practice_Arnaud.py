from ehrql import create_measures, months, years
from analysis.dataset_definition_patients_measures_Arnaud import dataset  # measures arnaud instead measures 
#from analysis.dataset_definition_patients_Arnaud import dataset  # as i haven't yet called all variables at patients level in patients measures.py, i will be calling it dataset ( inorder to use some variables. normally there are quite similar)
# opensafely exec ehrql:v1 generate-measures analysis/practice_variables/measures_practice_Arnaud.py --output output/measures_practice.csv

from ehrql import claim_permissions
claim_permissions("appointments")


#Grouping variables for measures

GROUPS = {
    #"sex": patients.sex,
    #"imd": patients.imd,
    #"ethnicity": dataset.ethnicity,
    "practice": dataset.practice,
    "month": dataset.start_date
    #"stp": patients.stp,
    #"region": patients.region,
}

# Create measures object
measures = create_measures()
measures.configure_disclosure_control(enabled=False)
measures.define_defaults(
    intervals=months(48).starting_on("2022-02-01"), # intervals=months(2).starting_on("2025-10-01") Here we may be able to see both GP and PF data in GP records.
    group_by=GROUPS
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
#"""
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
    denominator=measure_base_population
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
    denominator=measure_base_population & dataset.include_patient_uuti
)
measures.define_measure(
    name="gp_consultation_uti",
    numerator=dataset.numerator_gp_consultation_uti,
    denominator=measure_base_population & dataset.include_patient_uuti
    )

# Sinusitis
measures.define_measure(
    name="pf_consultation_sinusitis",
    numerator=dataset.numerator_pf_consultation_sinusitis,
    denominator=measure_base_population & dataset.include_patient_sinusitis
)
measures.define_measure(
    name="gp_consultation_sinusitis",
    numerator=dataset.numerator_gp_consultation_sinusitis,
    denominator=measure_base_population & dataset.include_patient_sinusitis
)
# Insect bites
measures.define_measure(
    name="pf_consultation_insectbite",
    numerator=dataset.numerator_pf_consultation_insectbite,
    denominator=measure_base_population & dataset.include_patient_insect_bites
)
measures.define_measure(
    name="gp_consultation_insectbite",
    numerator=dataset.numerator_gp_consultation_insectbite,
    denominator=measure_base_population & dataset.include_patient_insect_bites
)
# Otitis media
measures.define_measure(
    name="pf_consultation_otitismedia",
    numerator=dataset.numerator_pf_consultation_otitismedia,
    denominator=measure_base_population & dataset.include_patient_otitis_media
)

measures.define_measure(
    name="gp_consultation_otitismedia",
    numerator=dataset.numerator_gp_consultation_otitismedia,
    denominator=measure_base_population & dataset.include_patient_otitis_media
)
# Sore throat
measures.define_measure(
    name="pf_consultation_sorethroat",
    numerator=dataset.numerator_pf_consultation_sorethroat,
    denominator=measure_base_population & dataset.include_patient_sore_throat
)

measures.define_measure(
    name="gp_consultation_sorethroat",
    numerator=dataset.numerator_gp_consultation_sorethroat,
    denominator=measure_base_population & dataset.include_patient_sore_throat
)
# Shingles
measures.define_measure(
    name="pf_consultation_shingles",
    numerator=dataset.numerator_pf_consultation_shingles,
    denominator=measure_base_population & dataset.include_patient_shingles
)
measures.define_measure(
    name="gp_consultation_shingles",
    numerator=dataset.numerator_gp_consultation_shingles,
    denominator=measure_base_population & dataset.include_patient_shingles
)
# Impetigo
measures.define_measure(
    name="pf_consultation_impetigo",
    numerator=dataset.numerator_pf_consultation_impetigo,
    denominator=measure_base_population & dataset.include_patient_impetigo
)

measures.define_measure(
    name="gp_consultation_impetigo",
    numerator=dataset.numerator_gp_consultation_impetigo,
    denominator=measure_base_population & dataset.include_patient_impetigo
)

# All Pharmacy First conditions
measures.define_measure(
    name="pf_consultation_all_conditions",
    numerator=dataset.numerator_pf_consultation_all_conditions,
    denominator=measure_base_population & dataset.include_patient_overall_eligible
)
measures.define_measure(
    name="gp_consultation_all_conditions",
    numerator=dataset.numerator_gp_consultation_all_conditions,
    denominator=measure_base_population & dataset.include_patient_overall_eligible
)

#Controls conditions (gp)
# Acute bronchitis
measures.define_measure(
    name="gp_consultation_acutebronchitis_control",
    numerator=dataset.numerator_gp_consultation_acutebronchitis_control,
    denominator=measure_base_population & dataset.include_patient_sore_throat
)
# Allergic conjunctivitis
measures.define_measure(
    name="gp_consultation_conjunctivitisallergic_control",
    numerator=dataset.numerator_gp_consultation_conjunctivitisallergic_control,
    denominator=measure_base_population & dataset.include_patient_insect_bites
)
# Vulvovaginal candidiasis
measures.define_measure(
    name="gp_consultation_vulvovaginalcandidiasis_control",
    numerator=dataset.numerator_gp_consultation_vulvovaginalcandidiasis_control,
    denominator=measure_base_population & dataset.include_patient_uuti
)
#"""
#------------P4.Medications-------------------------------------------------------------------
#UTI 
measures.define_measure(
    name="pf_medication_uti",
    numerator=dataset.numerator_pf_medication_uti,
    denominator=measure_base_population & dataset.include_patient_uuti
)

measures.define_measure(
    name="gp_medication_uti",
    numerator=dataset.numerator_gp_medication_uti,
    denominator=measure_base_population & dataset.include_patient_uuti
)

#"""
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
# Infected insect bites
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
#
# All Pharmacy First conditions
measures.define_measure(
    name="pf_medication_all_conditions",
    numerator=dataset.numerator_pf_medication_all_conditions,
    denominator=measure_base_population & dataset.include_patient_overall_eligible
)
measures.define_measure(
    name="gp_medication_all_conditions",
    numerator=dataset.numerator_gp_medication_all_conditions,
    denominator=measure_base_population & dataset.include_patient_overall_eligible
)
#Controls conditions (gp)
# Acute bronchitis
measures.define_measure(
    name="gp_medication_acutebronchitis_control",
    numerator=dataset.numerator_gp_medication_acutebronchitis_control,
    denominator=measure_base_population & dataset.include_patient_sore_throat
)
# Allergic conjunctivitis
measures.define_measure(
    name="gp_medication_conjunctivitisallergic_control",
    numerator=dataset.numerator_gp_medication_conjunctivitisallergic_control,
    denominator=measure_base_population & dataset.include_patient_insect_bites
)
#"""
# Vulvovaginal candidiasis
measures.define_measure(
    name="gp_medication_vulvovaginalcandidiasis_control",
    numerator=dataset.numerator_gp_medication_vulvovaginalcandidiasis_control,
    denominator=measure_base_population & dataset.include_patient_uuti
)
# Specific medication

#IV.Specific antibiotics (two commonly prescribed antibiotics (before PF) for each condition)
# 1. UTI: Nitrofurantoin and trimethoprim
measures.define_measure(
    name="pf_nitrofurantoin_uti",
    numerator=dataset.numerator_pf_nitrofurantoin_uti,
    denominator=measure_base_population & dataset.include_patient_uuti
)

measures.define_measure(
    name="gp_nitrofurantoin_uti",
    numerator=dataset.numerator_gp_nitrofurantoin_uti,
    denominator=measure_base_population & dataset.include_patient_uuti
)

measures.define_measure(
    name="pf_trimethoprim_uti",
    numerator=dataset.numerator_pf_trimethoprim_uti,
    denominator=measure_base_population & dataset.include_patient_uuti
    )

measures.define_measure(
    name="gp_trimethoprim_uti",
    numerator=dataset.numerator_gp_trimethoprim_uti,
    denominator=measure_base_population & dataset.include_patient_uuti
)


# 2. Sinusitis: Phenoxymethylpenicillin and doxycycline
measures.define_measure(
    name="pf_phenoxymethylpenicillin_sinusitis",
    numerator=dataset.numerator_pf_phenoxymethylpenicillin_sinusitis,
    denominator=measure_base_population & dataset.include_patient_sinusitis
)

measures.define_measure(
    name="gp_phenoxymethylpenicillin_sinusitis",
    numerator=dataset.numerator_gp_phenoxymethylpenicillin_sinusitis,
    denominator=measure_base_population & dataset.include_patient_sinusitis
)

measures.define_measure(
    name="pf_doxycycline_sinusitis",
    numerator=dataset.numerator_pf_doxycycline_sinusitis,
    denominator=measure_base_population & dataset.include_patient_sinusitis
)

measures.define_measure(
    name="gp_doxycycline_sinusitis",
    numerator=dataset.numerator_gp_doxycycline_sinusitis,
    denominator=measure_base_population & dataset.include_patient_sinusitis
)


# 3. Insect bites: Flucloxacillin and clarithromycin
measures.define_measure(
    name="pf_flucloxacillin_insectbite",
    numerator=dataset.numerator_pf_flucloxacillin_insectbite,
    denominator=measure_base_population & dataset.include_patient_insect_bites
)

measures.define_measure(
    name="gp_flucloxacillin_insectbite",
    numerator=dataset.numerator_gp_flucloxacillin_insectbite,
    denominator=measure_base_population & dataset.include_patient_insect_bites
)
measures.define_measure(
    name="pf_clarithromycin_insectbite",
    numerator=dataset.numerator_pf_clarithromycin_insectbite,
    denominator=measure_base_population & dataset.include_patient_insect_bites
)

measures.define_measure(
    name="gp_clarithromycin_insectbite",
    numerator=dataset.numerator_gp_clarithromycin_insectbite,
    denominator=measure_base_population & dataset.include_patient_insect_bites
)

# 4. Otitis media: Amoxicillin and clarithromycin
measures.define_measure(
    name="pf_amoxicillin_otitismedia",
    numerator=dataset.numerator_pf_amoxicillin_otitismedia,
    denominator=measure_base_population & dataset.include_patient_otitis_media
)

measures.define_measure(
    name="gp_amoxicillin_otitismedia",
    numerator=dataset.numerator_gp_amoxicillin_otitismedia,
    denominator=measure_base_population & dataset.include_patient_otitis_media
)

measures.define_measure(
    name="pf_clarithromycin_otitismedia",
    numerator=dataset.numerator_pf_clarithromycin_otitismedia,
    denominator=measure_base_population & dataset.include_patient_otitis_media
)

measures.define_measure(
    name="gp_clarithromycin_otitismedia",
    numerator=dataset.numerator_gp_clarithromycin_otitismedia,
    denominator=measure_base_population & dataset.include_patient_otitis_media
)


# 5. Sore throat: Phenoxymethylpenicillin and clarithromycin
measures.define_measure(
    name="pf_phenoxymethylpenicillin_sorethroat",
    numerator=dataset.numerator_pf_phenoxymethylpenicillin_sorethroat,
    denominator=measure_base_population & dataset.include_patient_sore_throat
)

measures.define_measure(
    name="gp_phenoxymethylpenicillin_sorethroat",
    numerator=dataset.numerator_gp_phenoxymethylpenicillin_sorethroat,
    denominator=measure_base_population & dataset.include_patient_sore_throat
)

measures.define_measure(
    name="pf_clarithromycin_sorethroat",
    numerator=dataset.numerator_pf_clarithromycin_sorethroat,
    denominator=measure_base_population & dataset.include_patient_sore_throat,
    group_by=group
)

measures.define_measure(
    name="gp_clarithromycin_sorethroat",
    numerator=dataset.numerator_gp_clarithromycin_sorethroat,
    denominator=measure_base_population & dataset.include_patient_sore_throat
)


# 6. Shingles: Aciclovir and valaciclovir
measures.define_measure(
    name="pf_aciclovir_shingles",
    numerator=dataset.numerator_pf_aciclovir_shingles,
    denominator=measure_base_population & dataset.include_patient_shingles
)

measures.define_measure(
    name="gp_aciclovir_shingles",
    numerator=dataset.numerator_gp_aciclovir_shingles,
    denominator=measure_base_population & dataset.include_patient_shingles
)

measures.define_measure(
    name="pf_valaciclovir_shingles",
    numerator=dataset.numerator_pf_valaciclovir_shingles,
    denominator=measure_base_population & dataset.include_patient_shingles
)

measures.define_measure(
    name="gp_valaciclovir_shingles",
    numerator=dataset.numerator_gp_valaciclovir_shingles,
    denominator=measure_base_population & dataset.include_patient_shingles
)


# 7. Impetigo: Fusidic acid and flucloxacillin
measures.define_measure(
    name="pf_fusidic_acid_impetigo",
    numerator=dataset.numerator_pf_fusidic_acid_impetigo,
    denominator=measure_base_population & dataset.include_patient_impetigo
)

measures.define_measure(
    name="gp_fusidic_acid_impetigo",
    numerator=dataset.numerator_gp_fusidic_acid_impetigo,
    denominator=measure_base_population & dataset.include_patient_impetigo
)

measures.define_measure(
    name="pf_flucloxacillin_impetigo",
    numerator=dataset.numerator_pf_flucloxacillin_impetigo,
    denominator=measure_base_population & dataset.include_patient_impetigo
)

measures.define_measure(
    name="gp_flucloxacillin_impetigo",
    numerator=dataset.numerator_gp_flucloxacillin_impetigo,
    denominator=measure_base_population & dataset.include_patient_impetigo
)
