# This file defines the population and selects the fields that need to be included in the data for analysis. 
# Get new dummy tables: opensafely exec ehrql:v1 create-dummy-tables analysis/dataset_definition_patients.py dummy_tables
# gunzip -c output/dataset_definition_patients.csv.gz > output/dataset_definition_patients.csv

from ehrql import create_dataset, show, days, weeks, months, years, case, when, get_parameter,codelist_from_csv # Here we added codelist_from_csv to be able to read csv codelist
#----------------------useful link------------------------------------------
# "tpp" : is the real dataset used in OpenSAFELY analyses.("core" is generic)
#  "raw.tpp" :https://docs.opensafely.org/ehrql/reference/schemas/raw.tpp/ (accessible?, better for medication duration?)
# "tpp schemas": https://docs.opensafely.org/ehrql/reference/schemas/tpp/
# "tpp schemas": https://docs.opensafely.org/ehrql/reference/schemas/tpp/#practice_registrations.spanning
#  Command line use: https://docs.opensafely.org/ehrql/reference/cli/#dump-example-data 
#  Opensafely command line use: https://docs.opensafely.org/opensafely-cli/#installing-opensafely
#  Multiple times run: https://docs.opensafely.org/ehrql/how-to/multiple-time-periods/
#1.Pass parameters via the project.yaml
#2.The measures framework (best approach) : https://docs.opensafely.org/ehrql/explanation/measures/
from ehrql.tables.tpp import (patients, practice_registrations, clinical_events, addresses, 
                              ethnicity_from_sus,
                              emergency_care_attendances,appointments,medications) # I added medications to be able to assing treatment to the dataset
# import codelists
# from analysis import codelists #
import analysis.codelists as codelists
#from ehrql.tables.raw.tpp import medications # not sure if it work without permission
from analysis.pf_variable_library import (get_imd, get_latest_ethnicity, 
                                          select_events_between, select_events_from_codelist, select_events_by_consultation_id,
                                          has_event_count, ae_non_primary_diagnosis_matches)
from ehrql import claim_permissions # some tables require permissions to have access. 
claim_permissions("appointments")   # Access to this table requires the appointments permission:https://docs.opensafely.org/ehrql/reference/schemas/tpp/ 
#-------------------------------------------------------------------------------------------------------------------------------------------------------
# call my codelists (medication,PF conditions and their controls)  from analysis/codelists.py                          # airadukunda 
# changed it from "from codelists import" to "from analysis.codelists import" 
#1.PF conditions (gp_snomed_codelist) : airadukunda 
from analysis.codelists import (
    impetigo_codelist,           
    infected_insect_bites_codelist,
    otitis_media_codelist,
    shingles_codelist,
    sinusitis_codelist,
    sore_throat_codelist,
    uti_codelist,
    # 2.PF medication (gp_dmd_codelist)  : airadukunda
    aciclovir_codelist,
    amoxicillin_codelist,
    cefalexin_codelist,
    clindamycin_codelist,
    clarithromycin_codelist,
    co_amoxiclav_codelist,
    doxycycline_codelist,
    erythromycin_codelist,
    famciclovir_codelist,
    flucloxacillin_codelist,
    fosfomycin_codelist,
    fusidic_acid_cream_codelist,
    metronidazole_codelist,
    mupirocin_codelist,
    nitrofurantoin_codelist,
    phenoxymethylpenicillin_codelist,
    pivmecillinam_codelist,
    trimethoprim_codelist,
    valaciclovir_codelist,
    #3.PF control conditions (gp_snomed_codelist) :airadukunda
    acute_bronchitis_control_codelist,
    conjunctivitis_allergic_control_codelist,
    vulvovaginal_candidiasis_control_codelist,
    #4.PF controls medications
    antazoline_codelist,
    azelastine_codelist,
    epinastine_codelist,
    ketotifen_codelist,
    lodoxamide_codelist,
    olopatadine_codelist,
    sodium_cromoglicate_codelist,
    # Vaginal candidiasis
    clotrimazole_codelist,
    econazole_codelist,
    fenticonazole_codelist,
    fluconazole_codelist,
    #itraconazole_codelist,
    miconazole_codelist,
    )
#Ethnicity codelists
from analysis.codelists import (
    ethnicity_group6_codelist,
    ethnicity_group16_codelist,
    )
dataset = create_dataset()
dataset.configure_dummy_data(population_size=10) # The size can be increased from 500 to 1000 pop.airadukunda

# One month time period (to start with this is Nov 25) 
# start_date = "2025-10-31"     
# index_date = "2025-11-30"  
#start_date = get_parameter("start_date", default="2024-02-01")
start_date = get_parameter("start_date", default="2022-02-01") # 2 years before PF.airadukunda
index_date = start_date + months(1) - days(1)  # Here index_date means "last day of the month of start_date" #airadukunda
#index_date = start_date + days(0)             #  ---------------------"same day"----------------------------------------.

# We will need to run it multiple times: https://docs.opensafely.org/ehrql/how-to/multiple-time-periods/
#1.Pass parameters via the project.yaml
#2.The measures framework (this will be the best approach) : https://docs.opensafely.org/ehrql/explanation/measures/
# index_date = start_date + years(1)

"""
Monthly patient-level denominator + numerator dataset
Patient table key fields:
- Patient identifiers: patient_id, month (start_date, index_date), registration_status, alive_status, practice_id, region, 
- Demographics: age, sex, ethnicity, IMD
- Appointment count: scheduled; seen.
- PF consultation count for each condition
- GP consultation count for each condition
- GP consultation for each condition, by consultation mode (f2f, online, telephone, other)
- Eligibility/clinical characteristics flag (True/False)

 Eligibility/clinical characteristics flag for study population denominator:
- include_patient_otitis_media
- include_patient_sinusitis
- include_patient_sore_throat
- include_patient_insect_bites
- include_patient_shingles
- include_patient_impetigo
- include_patient_uti
- include_patient_overall_eligible: at least one condition

The above variables require:
- pregnant_this_month: True/False, developed by Helen
- bullous_impetigo_this_month
- recurrent_impetigo_this_year
- catheter_status
- recurrent_uti

A&E variables:
- total number of A&E attendances in month based on arrival_date
- for each PF condition, using GP wider SNOMED codelists, create variables for:
    - count of A&E attendances with primary diagnosis (diagnosis_01) match to the condition-specific GP codelist
    - flag for any non-primary diagnosis (diagnosis_02-24) match to the condition-specific GP codelist (T/F)

Appointment variables:
- total number of appointments that were scheduled to date in month (based on start_date)
- total number of appointments that were seen in month (based on seen_date)
       
Notes: 
- may have patients not eligible but PF consultation
- should do consistent criteria for registration_status for practice dataset
- run for every month - specify parameters in .yaml
- include detailed flags for each condition's inclusion and exclusion (may be good to have)
"""

########################################################
# Patient identifiers: alive_status, registration_status
alive = patients.is_alive_on(index_date) # alive at the end of month
# Only include the patient if they were registered for the whole month, 
# so registered before the month starts and not deregistered or died during the month
registered_start = practice_registrations.for_patient_on(start_date).exists_for_patient()
registered_index = practice_registrations.for_patient_on(index_date).exists_for_patient()
registration = practice_registrations.for_patient_on(index_date).exists_for_patient()
# Demographics: sex, age, patient_imd
sex = patients.sex
age = patients.age_on(index_date)

# Define population 
# base_population = patients.exists_for_patient()
age_valid = (patients.age_on(index_date) <= 120)   # "Exclude any patients over 120 years old as the date of birth is most likely to be missing"
base_population = alive & registered_start & registered_index & age_valid 
dataset.define_population(base_population) # include all patients or those alive and registered

dataset.start_date = case(when(base_population).then(start_date))
dataset.index_date = case(when(base_population).then(index_date))
#Demographic_variables 
dataset.registered_start = registered_start
dataset.registered_index = registered_index
dataset.alive = alive
dataset.sex = sex 
dataset.age = age
dataset.age_band = case(                         # Age band (15-49) for women.airadukunda
        when(age < 15).then("0-14"),
        when(age < 50).then("15-49"),
        when(age >= 50).then("50+"),
        otherwise="missing",
)
dataset.date_of_birth = patients.date_of_birth   # debug
dataset.imd = get_imd(addresses, index_date)
dataset.ethnicity = get_latest_ethnicity(index_date,clinical_events,codelists.ethnicity_group16_codelist,ethnicity_from_sus,grouping=16,)
# Patient identifiers: practice_id, stp, region
dataset.practice = practice_registrations.for_patient_on(index_date).practice_pseudo_id
dataset.stp = practice_registrations.for_patient_on(index_date).practice_stp
# dataset.region = practice_registrations.for_patient_on(index_date).practice_nuts1_region_name
dataset.region = case(
    when(practice_registrations.for_patient_on(index_date).practice_nuts1_region_name.is_null()).then("Missing"),
    otherwise=practice_registrations.for_patient_on(index_date).practice_nuts1_region_name,
)
"""  
dataset.protocol = case(when(patients.exists_for_patient()).then("Protocol4"), otherwise="Protocol4",)
"""
"""
The dataset is constructed using the following approach:
    -Consultations and medications are stratified by healthcare setting: Community Pharmacy (CP), General Practice (GP).
    -As this study focuses on antimicrobial prescribing at the general practice level , the Protocol 4 dataset will compare GP and CPmedication data for descriptive analyses.
    -The Interrupted Time Series Analysis (ITSA) will be conducted at the GP level, using prescriptions issued by General Practitioners as the outcome. 
    ->We expect to observe a decrease in GP prescribing following the introduction of Pharmacy First, reflecting a potential shift in prescribing from GP practices to Community Pharmacies
"""
#Approach 0 : PF conditions and their medications for both GP,CP settings .

# Clinical events and Medications  between start and  index dates 
# a.On index date (time varying index date?)
# recent_medication = medications.where(medications.date == index_date)
# recent_clinical_event = clinical_events.where(clinical_events.date == index_date) # Clinical events are identified by SNOMED-CT code: https://docs.opensafely.org/ehrql/tutorials/introduction-to-ehrql/more-complex-transformations/

# b.Between two dates (start_date, index_date) #this can be a montly or daily counting

recent_medication = medications.where(medications.date.is_on_or_between(start_date , index_date))
recent_clinical_event = clinical_events.where(clinical_events.date.is_on_or_between(start_date,index_date))
# Delay in prescriptions for sensitivity analysis 
recent_medication_lag7 = medications.where(medications.date.is_on_or_between(start_date , index_date + days(7)))

# Medications 
# PF events
all_pf_conditions_codelist = (
    uti_codelist +
    sinusitis_codelist+ 
    infected_insect_bites_codelist +
    otitis_media_codelist+
    sore_throat_codelist+
    shingles_codelist+
    impetigo_codelist
)
pharmacy_first_events = (
    recent_clinical_event
    .where(clinical_events.snomedct_code.is_in(all_pf_conditions_codelist))
)
# PF medication

all_pharmacy_first_medications = (
    aciclovir_codelist
    + amoxicillin_codelist
    + cefalexin_codelist
    + clarithromycin_codelist
    + clindamycin_codelist
    + co_amoxiclav_codelist
    + doxycycline_codelist
    + erythromycin_codelist
    + famciclovir_codelist
    + flucloxacillin_codelist
    + fosfomycin_codelist
    + fusidic_acid_cream_codelist
    + metronidazole_codelist
    + mupirocin_codelist
    + nitrofurantoin_codelist
    + phenoxymethylpenicillin_codelist
    + pivmecillinam_codelist
    + trimethoprim_codelist
    + valaciclovir_codelist
)
dataset.has_medication = (
    recent_medication
    .where(medications.dmd_code.is_in(all_pharmacy_first_medications))
    .where(medications.consultation_id.is_in(pharmacy_first_events.consultation_id))
    .exists_for_patient()
    .as_int()
)
# 0.Medication and clincal event matching approach (date, consultation ID)--------------------------------------------------------------------------------------------------------------------------------
# 0.1.Same date ?
# uti on the same date
# uti_event = (
   # recent_clinical_event
    #.where(clinical_events.snomedct_code.is_in(uti_codelist))
    #.sort_by(clinical_events.date)
    #.last_for_patient()
#)
#dataset.uti_date = uti_event.date
#dataset.nitrofurantoin_on_uti_date = (
    #medications
    #.where(medications.dmd_code.is_in(nitrofurantoin_codelist))
    #.where(medications.date == dataset.uti_date)
    #.exists_for_patient()
    #.as_int()
#)
# OR directly
#uuti_date = (
 #  recent_clinical_event
   # .where(clinical_events.snomedct_code.is_in(uti_codelist))
    #.sort_by(clinical_events.date)
    #.last_for_patient()
    #.date
 #)
 #dataset.nnitrofurantoin_on_uti_date = (
 #   medications
   # .where(medications.dmd_code.is_in(nitrofurantoin_codelist))
   # .where(medications.date == uuti_date)
   # .exists_for_patient()
   # .as_int()
#)
# 0.2.Same consultation_ID
"""
UTI_events = (
    recent_clinical_event
    .where(clinical_events.snomedct_code.is_in(uti_codelist))
)
dataset.has_UTI = UTI_events.exists_for_patient().as_int()
dataset.nitrofurantoin_on_UTI_consultation = (
    medications
    .where(medications.dmd_code.is_in(nitrofurantoin_codelist))
    .where(medications.consultation_id.is_in( UTI_events.consultation_id))
    .exists_for_patient()
    .as_int()
)
#-------------------Each PF conditions and its medication ------------------------------------------------------------------------------------------------------------------
#1.Urinary Tract Infections ((female, age 15–49)) 
#1.a.Clinical event : This will need to consider the inclusion and exclusion criteria (defined below in Weiyao codes) 
# Eligible  
female_15_49 = (  
    (patients.sex == "female") &
    (patients.age_on(index_date) >= 15) &
    (patients.age_on(index_date) <= 49)
)
uti_events = (              # This code check if the clinical event happened between start and index date was uti 
    recent_clinical_event
    .where(clinical_events.snomedct_code.is_in(uti_codelist))
    .where(female_15_49)    #Inclusion and exclusion criteria.Here we also need to consider pregnancy ( True or False)
    )
dataset.has_uti = uti_events.exists_for_patient().as_int() # 0 if no ,1 otherwise : better for daily not for monthly 
#Event count
#dataset.uti_count = (                  #This count uti events.A patient can have more than one event's code for the same consultation (uti, cystitis,..) 
 #   uti_events.count_for_patient()
#)
dataset.uti_consultation_count = (       #This count uti consultations : This should be more accurate than "uti_count" because one consultaion can have more than 1 code for the same condition (especialy when GP want to add more description.For ex:Diagnosis (UTI)+Symptoms (Dysuria),or Diagnosis(UTI)+Specification( Cystitis) 
    uti_events.consultation_id.count_distinct_for_patient()
)
#1.b.Treatment  
#1.b.1.Nitrofurantoin (nitrofurantoin_on_uti_consultation) 
dataset.nitrofurantoin_uti = (
    recent_medication
    .where(medications.dmd_code.is_in(nitrofurantoin_codelist))
    .where(medications.consultation_id.is_in(uti_events.consultation_id))
    .where(female_15_49)
    .exists_for_patient()
    .as_int()
)
#1.b.2.Trimethoprim
dataset.trimethoprim_uti = (
    recent_medication
    .where(medications.dmd_code.is_in(trimethoprim_codelist))
    .where(medications.consultation_id.is_in(uti_events.consultation_id))
    .where(female_15_49)
    .exists_for_patient()
    .as_int()
)
#1.b.3.Fosfomycin
dataset.fosfomycin_uti = (
    recent_medication
    .where(medications.dmd_code.is_in(fosfomycin_codelist))
    .where(medications.consultation_id.is_in(uti_events.consultation_id))
    .where(female_15_49)
    .exists_for_patient()
    .as_int()
)
#1.b.4.Pivmecillinam
dataset.pivmecillinam_uti = (
    recent_medication
    .where(medications.dmd_code.is_in(pivmecillinam_codelist))
    .where(medications.consultation_id.is_in( uti_events.consultation_id))
    .where(female_15_49)
    .exists_for_patient()
    .as_int()
)
#1.b.5.Co-amoxiclav
dataset.co_amoxiclav_uti = (
    recent_medication
    .where(medications.dmd_code.is_in(co_amoxiclav_codelist))
    .where(medications.consultation_id.is_in(uti_events.consultation_id))
    .where(female_15_49)
    .exists_for_patient()
    .as_int()
)
#1.b.6.Cefalexin
dataset.cefalexin_uti = (
    recent_medication
    .where(medications.dmd_code.is_in(cefalexin_codelist))
    .where( medications.consultation_id.is_in(uti_events.consultation_id))
    .where(female_15_49)
    .exists_for_patient()
    .as_int()
)
#1.b.7.Amoxicillin
dataset.amoxicillin_uti = (
    recent_medication
    .where(medications.dmd_code.is_in(amoxicillin_codelist))
    .where(medications.consultation_id.is_in(uti_events.consultation_id))
    .where(female_15_49)
    .exists_for_patient()
    .as_int()
)
#1.c.all antimicrobials (we can sum all 1.b)
uti_all_treatment_codelist = (  # source :  https://docs.opensafely.org/ehrql/how-to/codelists/
    nitrofurantoin_codelist
    + trimethoprim_codelist
    + fosfomycin_codelist
    + pivmecillinam_codelist
    + co_amoxiclav_codelist
    + cefalexin_codelist
    + amoxicillin_codelist
)
dataset.uti_all_treatment = (
    recent_medication
    .where(recent_medication.dmd_code.is_in(uti_all_treatment_codelist))
    .where(medications.consultation_id.is_in(uti_events.consultation_id))
    .where(female_15_49)
    .exists_for_patient()
    .as_int()
)
# count of the number of UTI antimicrobial categories prescribed : number of UTI antimicrobial categories prescribed
dataset.uti_treatment_count = (
    dataset.nitrofurantoin_uti
    + dataset.trimethoprim_uti
    + dataset.fosfomycin_uti
    + dataset.pivmecillinam_uti
    + dataset.co_amoxiclav_uti
    + dataset.cefalexin_uti
    + dataset.amoxicillin_uti
)
#Binary indicator for whether any UTI treatment was prescribed : 1 if any UTI antimicrobial was prescribed, otherwise 0
dataset.uti_treated = (
    (
        dataset.nitrofurantoin_uti
        + dataset.trimethoprim_uti
        + dataset.fosfomycin_uti
        + dataset.pivmecillinam_uti
        + dataset.co_amoxiclav_uti
        + dataset.cefalexin_uti
        + dataset.amoxicillin_uti
    ) > 0
).as_int()
#2.Impetigo
#2.a.Clinical event
impetigo_events = (
    recent_clinical_event
    .where(clinical_events.snomedct_code.is_in(impetigo_codelist))
)
dataset.has_impetigo = (
    impetigo_events.exists_for_patient()
    .as_int()
)
dataset.impetigo_consultation_count = (     
    impetigo_events.consultation_id.count_distinct_for_patient()
)
#2.b.Treatment
#2.b.1.Fusidic acid cream
dataset.fusidic_acid_cream_impetigo = (
    recent_medication
    .where(medications.dmd_code.is_in(fusidic_acid_cream_codelist))
    .where(medications.consultation_id.is_in(impetigo_events.consultation_id) )
    .exists_for_patient()
    .as_int()
)
#2.b.2.Flucloxacillin
dataset.flucloxacillin_impetigo = (
    recent_medication
    .where(medications.dmd_code.is_in(flucloxacillin_codelist))
    .where(medications.consultation_id.is_in( impetigo_events.consultation_id))
    .exists_for_patient()
    .as_int()
)
#2.b.3.Clarithromycin
dataset.clarithromycin_impetigo = (
    recent_medication
    .where(medications.dmd_code.is_in(clarithromycin_codelist))
    .where(medications.consultation_id.is_in(impetigo_events.consultation_id))
    .exists_for_patient()
    .as_int()
)
#2.b.4.Erythromycin
dataset.erythromycin_impetigo = (
    recent_medication
    .where(medications.dmd_code.is_in(erythromycin_codelist))
    .where(medications.consultation_id.is_in( impetigo_events.consultation_id))
    .exists_for_patient()
    .as_int()
)
#2.b.5.Mupirocin
dataset.mupirocin_impetigo = (
    recent_medication
    .where(medications.dmd_code.is_in(mupirocin_codelist))
    .where(medications.consultation_id.is_in( impetigo_events.consultation_id))
    .exists_for_patient()
    .as_int()
)
#2.c.All recommended impetigo treatments
impetigo_all_treatment_codelist = (
    fusidic_acid_cream_codelist
    + flucloxacillin_codelist
    + clarithromycin_codelist
    + erythromycin_codelist
    + mupirocin_codelist
)

dataset.impetigo_all_treatment = (
    recent_medication
    .where(medications.dmd_code.is_in(impetigo_all_treatment_codelist))
    .where(medications.consultation_id.is_in(impetigo_events.consultation_id))
    .exists_for_patient()
    .as_int()
)

#2.d.Number of impetigo antimicrobial categories prescribed
dataset.impetigo_treatment_count = (
    dataset.fusidic_acid_cream_impetigo
    + dataset.flucloxacillin_impetigo
    + dataset.clarithromycin_impetigo
    + dataset.erythromycin_impetigo
    + dataset.mupirocin_impetigo
)
#2.e.Binary indicator for whether any impetigo treatment was prescribed
dataset.impetigo_treated = (
    (
        dataset.fusidic_acid_cream_impetigo
        + dataset.flucloxacillin_impetigo
        + dataset.clarithromycin_impetigo
        + dataset.erythromycin_impetigo
        + dataset.mupirocin_impetigo
    ) > 0
).as_int()

#3. Insect bites

#3.a.Clinical event
insect_bite_events = (
    recent_clinical_event
    .where(clinical_events.snomedct_code.is_in(infected_insect_bites_codelist))
)
dataset.has_insecte_bite = (
    insect_bite_events.exists_for_patient()
    .as_int()
)
dataset.insect_bite_consultation_count = (     
    insect_bite_events.consultation_id.count_distinct_for_patient()
)
#3.b.Treatment
# (Flucloxacillin/Clarithromycin/Erythromycin/Co-amoxiclav/
#  Metronidazole/Clindamycin/Doxycycline)

#3.b.1.Flucloxacillin
dataset.flucloxacillin_insect_bite = (
    recent_medication
    .where(medications.dmd_code.is_in(flucloxacillin_codelist))
    .where( medications.consultation_id.is_in(insect_bite_events.consultation_id))
    .exists_for_patient()
    .as_int()
)
#3.b.2.Clarithromycin
dataset.clarithromycin_insect_bite = (
    recent_medication
    .where(medications.dmd_code.is_in(clarithromycin_codelist))
    .where(medications.consultation_id.is_in(insect_bite_events.consultation_id))
    .exists_for_patient()
    .as_int()
)
#3.b.3.Erythromycin
dataset.erythromycin_insect_bite = (
    recent_medication
    .where(medications.dmd_code.is_in(erythromycin_codelist))
    .where(medications.consultation_id.is_in(insect_bite_events.consultation_id))
    .exists_for_patient()
    .as_int()
)
#3.b.4.Co-amoxiclav
dataset.co_amoxiclav_insect_bite = (
    recent_medication
    .where(medications.dmd_code.is_in(co_amoxiclav_codelist))
    .where(medications.consultation_id.is_in(insect_bite_events.consultation_id))
    .exists_for_patient()
    .as_int()
)
#3.b.5.Metronidazole
dataset.metronidazole_insect_bite = (
    recent_medication
    .where(medications.dmd_code.is_in(metronidazole_codelist))
    .where(medications.consultation_id.is_in(insect_bite_events.consultation_id))
    .exists_for_patient()
    .as_int()
)
#3.b.6.Clindamycin
dataset.clindamycin_insect_bite = (
    recent_medication
    .where(medications.dmd_code.is_in(clindamycin_codelist))
    .where(medications.consultation_id.is_in(insect_bite_events.consultation_id))
    .exists_for_patient()
    .as_int()
)
#3.b.7.Doxycycline
dataset.doxycycline_insect_bite = (
    recent_medication
    .where(medications.dmd_code.is_in(doxycycline_codelist))
    .where(medications.consultation_id.is_in( insect_bite_events.consultation_id ))
    .exists_for_patient()
    .as_int()
)
#3.c.All recommended insect bite treatments
insect_bite_all_treatment_codelist = (
    flucloxacillin_codelist
    + clarithromycin_codelist
    + erythromycin_codelist
    + co_amoxiclav_codelist
    + metronidazole_codelist
    + clindamycin_codelist
    + doxycycline_codelist
)
dataset.insect_bite_all_treatment = (
    recent_medication
    .where(medications.dmd_code.is_in(insect_bite_all_treatment_codelist))
    .where(medications.consultation_id.is_in(insect_bite_events.consultation_id))
    .exists_for_patient()
    .as_int()
)
#3.d.Number of insect bite antimicrobial categories prescribed
dataset.insect_bite_treatment_count = (
    dataset.flucloxacillin_insect_bite
    + dataset.clarithromycin_insect_bite
    + dataset.erythromycin_insect_bite
    + dataset.co_amoxiclav_insect_bite
    + dataset.metronidazole_insect_bite
    + dataset.clindamycin_insect_bite
    + dataset.doxycycline_insect_bite
)
#3.e.Binary indicator for whether any insect bite treatment was prescribed
dataset.insect_bite_treated = (
    (
        dataset.flucloxacillin_insect_bite
        + dataset.clarithromycin_insect_bite
        + dataset.erythromycin_insect_bite
        + dataset.co_amoxiclav_insect_bite
        + dataset.metronidazole_insect_bite
        + dataset.clindamycin_insect_bite
        + dataset.doxycycline_insect_bite
    ) > 0
).as_int()

#4. Otitis media
#4.a.Clinical event
otitis_media_events = (
    recent_clinical_event
    .where(clinical_events.snomedct_code.is_in(otitis_media_codelist))
)
dataset.has_otitis_media = (
    otitis_media_events.exists_for_patient()
    .as_int()
)
dataset.otitis_media_consultation_count = (     
    otitis_media_events.consultation_id.count_distinct_for_patient()
)
#4.b.Treatment
# (Amoxicillin/Clarithromycin/Erythromycin/Co-amoxiclav)

#4.b.1.Amoxicillin
dataset.amoxicillin_otitis_media = (
    recent_medication
    .where(medications.dmd_code.is_in(amoxicillin_codelist))
    .where( medications.consultation_id.is_in(otitis_media_events.consultation_id))
    .exists_for_patient()
    .as_int()
)
#4.b.2.Clarithromycin
dataset.clarithromycin_otitis_media = (
    recent_medication
    .where(medications.dmd_code.is_in(clarithromycin_codelist))
    .where(medications.consultation_id.is_in(otitis_media_events.consultation_id))
    .exists_for_patient()
    .as_int()
)
#4.b.3.Erythromycin
dataset.erythromycin_otitis_media = (
    recent_medication
    .where(medications.dmd_code.is_in(erythromycin_codelist))
    .where(medications.consultation_id.is_in( otitis_media_events.consultation_id))
    .exists_for_patient()
    .as_int()
)
#4.b.4.Co-amoxiclav
dataset.co_amoxiclav_otitis_media = (
    recent_medication
    .where(medications.dmd_code.is_in(co_amoxiclav_codelist))
    .where(medications.consultation_id.is_in(otitis_media_events.consultation_id))
    .exists_for_patient()
    .as_int()
)
#4.c.All recommended otitis media treatments
otitis_media_all_treatment_codelist = (
    amoxicillin_codelist
    + clarithromycin_codelist
    + erythromycin_codelist
    + co_amoxiclav_codelist
)
dataset.otitis_media_all_treatment = (
    recent_medication
    .where(medications.dmd_code.is_in(otitis_media_all_treatment_codelist))
    .where(medications.consultation_id.is_in(otitis_media_events.consultation_id) )
    .exists_for_patient()
    .as_int()
)
#4.d.Number of otitis media antimicrobial categories prescribed
dataset.otitis_media_treatment_count = (
    dataset.amoxicillin_otitis_media
    + dataset.clarithromycin_otitis_media
    + dataset.erythromycin_otitis_media
    + dataset.co_amoxiclav_otitis_media
)

#4.e.Binary indicator for whether any otitis media treatment was prescribed
dataset.otitis_media_treated = (
    (
        dataset.amoxicillin_otitis_media
        + dataset.clarithromycin_otitis_media
        + dataset.erythromycin_otitis_media
        + dataset.co_amoxiclav_otitis_media
    ) > 0
).as_int()

#5. Shingles
#5.a.Clinical event
shingles_events = (
    recent_clinical_event
    .where(clinical_events.snomedct_code.is_in(shingles_codelist))
)
dataset.has_shingles = (
    shingles_events.exists_for_patient()
    .as_int()
)
dataset.shingles_consultation_count = (     
    shingles_events.consultation_id.count_distinct_for_patient()
)
#5.b.Treatment
# (Aciclovir/Valaciclovir/Famciclovir)
#5.b.1.Aciclovir
dataset.aciclovir_shingles = (
    recent_medication
    .where(medications.dmd_code.is_in(aciclovir_codelist))
    .where(medications.consultation_id.is_in(shingles_events.consultation_id))
    .exists_for_patient()
    .as_int()
)
#5.b.2.Valaciclovir
dataset.valaciclovir_shingles = (
    recent_medication
    .where(medications.dmd_code.is_in(valaciclovir_codelist))
    .where(medications.consultation_id.is_in(shingles_events.consultation_id))
    .exists_for_patient()
    .as_int()
)
#5.b.3.Famciclovir
dataset.famciclovir_shingles = (
    recent_medication
    .where(medications.dmd_code.is_in(famciclovir_codelist))
    .where(medications.consultation_id.is_in(shingles_events.consultation_id))
    .exists_for_patient()
    .as_int()
)
#5.c.All recommended shingles treatments
shingles_all_treatment_codelist = (
    aciclovir_codelist
    + valaciclovir_codelist
    + famciclovir_codelist
)
dataset.shingles_all_treatment = (
    recent_medication
    .where(medications.dmd_code.is_in(shingles_all_treatment_codelist))
    .where(medications.consultation_id.is_in(shingles_events.consultation_id))
    .exists_for_patient()
    .as_int()
)
#5.d.Number of shingles antiviral categories prescribed
dataset.shingles_treatment_count = (
    dataset.aciclovir_shingles
    + dataset.valaciclovir_shingles
    + dataset.famciclovir_shingles
)
#5.e.Binary indicator for whether any shingles treatment was prescribed
dataset.shingles_treated = (
    (
        dataset.aciclovir_shingles
        + dataset.valaciclovir_shingles
        + dataset.famciclovir_shingles
    ) > 0
).as_int()
#6. Sinusitis
#6.a.Clinical event
sinusitis_events = (
    recent_clinical_event
    .where(clinical_events.snomedct_code.is_in(sinusitis_codelist))
)
dataset.has_sinusitis = (
    sinusitis_events.exists_for_patient()
    .as_int()
)
dataset.sinusitis_consultation_count = (     
    sinusitis_events.consultation_id.count_distinct_for_patient()
)
#6.b.Treatment
# (Phenoxymethylpenicillin/Clarithromycin/Erythromycin/Doxycycline/Co-amoxiclav)
#6.b.1.Phenoxymethylpenicillin
dataset.phenoxymethylpenicillin_sinusitis = (
    recent_medication
    .where(medications.dmd_code.is_in(phenoxymethylpenicillin_codelist))
    .where(medications.consultation_id.is_in(sinusitis_events.consultation_id ))
    .exists_for_patient()
    .as_int()
)
#6.b.2.Clarithromycin
dataset.clarithromycin_sinusitis = (
    recent_medication
    .where(medications.dmd_code.is_in(clarithromycin_codelist))
    .where(medications.consultation_id.is_in(sinusitis_events.consultation_id))
    .exists_for_patient()
    .as_int()
)
#6.b.3.Erythromycin
dataset.erythromycin_sinusitis = (
    recent_medication
    .where(medications.dmd_code.is_in(erythromycin_codelist))
    .where(medications.consultation_id.is_in(sinusitis_events.consultation_id))
    .exists_for_patient()
    .as_int()
)
#6.b.4.Doxycycline
dataset.doxycycline_sinusitis = (
    recent_medication
    .where(medications.dmd_code.is_in(doxycycline_codelist))
    .where(medications.consultation_id.is_in(sinusitis_events.consultation_id))
    .exists_for_patient()
    .as_int()
)
#6.b.5.Co-amoxiclav
dataset.co_amoxiclav_sinusitis = (
    recent_medication
    .where(medications.dmd_code.is_in(co_amoxiclav_codelist))
    .where(medications.consultation_id.is_in(sinusitis_events.consultation_id))
    .exists_for_patient()
    .as_int()
)
#6.c.All recommended sinusitis treatments
sinusitis_all_treatment_codelist = (
    phenoxymethylpenicillin_codelist
    + clarithromycin_codelist
    + erythromycin_codelist
    + doxycycline_codelist
    + co_amoxiclav_codelist
)
dataset.sinusitis_all_treatment = (
    recent_medication
    .where(medications.dmd_code.is_in(sinusitis_all_treatment_codelist))
    .where(medications.consultation_id.is_in(sinusitis_events.consultation_id))
    .exists_for_patient()
    .as_int()
)
#6.d.Number of sinusitis antimicrobial categories prescribed
dataset.sinusitis_treatment_count = (
    dataset.phenoxymethylpenicillin_sinusitis
    + dataset.clarithromycin_sinusitis
    + dataset.erythromycin_sinusitis
    + dataset.doxycycline_sinusitis
    + dataset.co_amoxiclav_sinusitis
)
#6.e.Binary indicator for whether any sinusitis treatment was prescribed
dataset.sinusitis_treated = (
    (
        dataset.phenoxymethylpenicillin_sinusitis
        + dataset.clarithromycin_sinusitis
        + dataset.erythromycin_sinusitis
        + dataset.doxycycline_sinusitis
        + dataset.co_amoxiclav_sinusitis
    ) > 0
).as_int()
#7. Sore throat
#7.a.Clinical event
sore_throat_events = (
    recent_clinical_event
    .where(clinical_events.snomedct_code.is_in(sore_throat_codelist))
)
dataset.has_sore_throat = (
    sore_throat_events.exists_for_patient()
    .as_int()
)
dataset.sore_throat_consultation_count = (     
    sore_throat_events.consultation_id.count_distinct_for_patient()
)
#7.b.Treatment
# (Phenoxymethylpenicillin/Clarithromycin/Erythromycin)
#7.b.1.Phenoxymethylpenicillin
dataset.phenoxymethylpenicillin_sore_throat = (
    recent_medication
    .where(medications.dmd_code.is_in(phenoxymethylpenicillin_codelist))
    .where(medications.consultation_id.is_in(sore_throat_events.consultation_id))
    .exists_for_patient()
    .as_int()
)
#7.b.2.Clarithromycin
dataset.clarithromycin_sore_throat = (
    recent_medication
    .where(medications.dmd_code.is_in(clarithromycin_codelist))
    .where(medications.consultation_id.is_in(sore_throat_events.consultation_id))
    .exists_for_patient()
    .as_int()
)
#7.b.3.Erythromycin
dataset.erythromycin_sore_throat = (
    recent_medication
    .where(medications.dmd_code.is_in(erythromycin_codelist))
    .where(medications.consultation_id.is_in(sore_throat_events.consultation_id))
    .exists_for_patient()
    .as_int()
)
#7.c.All recommended sore throat treatments
sore_throat_all_treatment_codelist = (
    phenoxymethylpenicillin_codelist
    + clarithromycin_codelist
    + erythromycin_codelist
)
dataset.sore_throat_all_treatment = (
    recent_medication
    .where(medications.dmd_code.is_in(sore_throat_all_treatment_codelist))
    .where(medications.consultation_id.is_in(sore_throat_events.consultation_id))
    .exists_for_patient()
    .as_int()
)
#7.d.Number of sore throat antimicrobial categories prescribed
dataset.sore_throat_treatment_count = (
    dataset.phenoxymethylpenicillin_sore_throat
    + dataset.clarithromycin_sore_throat
    + dataset.erythromycin_sore_throat
)
#7.e.Binary indicator for whether any sore throat treatment was prescribed
dataset.sore_throat_treated = (
    (
        dataset.phenoxymethylpenicillin_sore_throat
        + dataset.clarithromycin_sore_throat
        + dataset.erythromycin_sore_throat
    ) > 0
).as_int()
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~#
# A.PF CONDITIONS (all conditions combined)        #
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~#
gp_pf_events = (
    recent_clinical_event
    .where(
        clinical_events.snomedct_code.is_in(                 #here i can use codelists.pf_conditions["all_pf_conditions"]
            impetigo_codelist                          #1
            + infected_insect_bites_codelist           #2
            + otitis_media_codelist                    #3
            + shingles_codelist                        #4
            + sinusitis_codelist                       #5
            + sore_throat_codelist                     #6
            + uti_codelist                             #7
        )
    )
)
dataset.has_gp_pf_condition = (
    gp_pf_events.exists_for_patient()
    .as_int()
)
dataset.gp_pf_consultation_count = (                                 # denominator for measure?
    gp_pf_events.consultation_id.count_distinct_for_patient()
)
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~#
# B.PF MEDICATIONS (all medications combined)                    #
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~#
gp_pf_antimicrobial_prescribing = (
    recent_medication
    .where(
        medications.dmd_code.is_in(
            aciclovir_codelist
            + amoxicillin_codelist
            + cefalexin_codelist
            + clindamycin_codelist
            + clarithromycin_codelist
            + co_amoxiclav_codelist
            + doxycycline_codelist
            + erythromycin_codelist
            + famciclovir_codelist
            + flucloxacillin_codelist
            + fosfomycin_codelist
            + fusidic_acid_cream_codelist
            + metronidazole_codelist
            + mupirocin_codelist
            + nitrofurantoin_codelist
            + phenoxymethylpenicillin_codelist
            + pivmecillinam_codelist
            + trimethoprim_codelist
            + valaciclovir_codelist
        )
    )
    .where(medications.consultation_id.is_in(gp_pf_events.consultation_id) )
)
dataset.pf_antimicrobial_prescribed = (     # numerator for measure
    gp_pf_antimicrobial_prescribing
    .exists_for_patient()
    .as_int()
)
dataset.pf_antimicrobial_consultation_count = (
    gp_pf_antimicrobial_prescribing
    .consultation_id
    .count_distinct_for_patient()
)

#------------------------------Controls--------------------------------------------------------------------------------------
# 8. Acute Bronchitis
#8.a. Clinical event
acute_bronchitis_events = (
    recent_clinical_event
    .where(clinical_events.snomedct_code.is_in(acute_bronchitis_control_codelist))
)
dataset.has_acute_bronchitis = (                      # for daily count (because if this happen twice a month, it remain 0 or 1)
    acute_bronchitis_events.exists_for_patient()
    .as_int()
)
dataset.acute_bronchitis_consultation_count = (
    acute_bronchitis_events.consultation_id.count_distinct_for_patient()
)
#8.b. Treatment (from  medication codelist developed for  PF controls) 
# Ex: Amoxicillin
dataset.amoxicillin_acute_bronchitis = (
    recent_medication
    .where(medications.dmd_code.is_in(amoxicillin_codelist))
    .where( medications.consultation_id.is_in(acute_bronchitis_events.consultation_id))
    .exists_for_patient()
    .as_int()
)
# 9. Allergic Conjunctivitis
#9.a. Clinical event
allergic_conjunctivitis_events = (
    recent_clinical_event
    .where(clinical_events.snomedct_code.is_in(conjunctivitis_allergic_control_codelist))
)
dataset.has_allergic_conjunctivitis = (
    allergic_conjunctivitis_events.exists_for_patient()
    .as_int()
)
dataset.allergic_conjunctivitis_consultation_count = (
    allergic_conjunctivitis_events.consultation_id.count_distinct_for_patient()
)
#9.b.Treatment
# 10. Vulvovaginal Candidiasis
#10.a. Clinical event
vulvovaginal_candidiasis_events = (
    recent_clinical_event
    .where(clinical_events.snomedct_code.is_in(vulvovaginal_candidiasis_control_codelist)))
dataset.has_vulvovaginal_candidiasis = (
    vulvovaginal_candidiasis_events.exists_for_patient()
    .as_int()
)
dataset.vulvovaginal_candidiasis_consultation_count = (
    vulvovaginal_candidiasis_events.consultation_id.count_distinct_for_patient()
)
#10.b. Treatment
# : Fluconazole
"""
######################################################## P4
'''
GP + Pharmacy First combined consultations

Outputs:
- gp_pf_consultation_general
- numerator_gp_pf_consultation_{name}
- numerator_gp_pf_date_{name}

P4
- numerator_gp_pf_medication_{name}
- numerator_gp_pf_medication_date_{name}
- numerator_gp_pf_{medication_name}_{name}
- numerator_gp_pf_{medication_name}_date_{name}
'''
""""
gp_pf_selected_events = select_events_between(clinical_events, start_date, index_date)
# Combined GP + PF condition codes
gp_pf_conditions = {
    "uti": codelists.uti_codelist,
    "sinusitis": codelists.sinusitis_codelist,
    "insectbite": codelists.infected_insect_bites_codelist,
    "otitismedia": codelists.otitis_media_codelist,
    "sorethroat": codelists.sore_throat_codelist,
    "shingles": codelists.shingles_codelist,
    "impetigo": codelists.impetigo_codelist,
}
#Controls
control_conditions_gp_pf_codes = {
    # "lowerbackpain": codelists.gp_snomed_codelist_lower_back_pain,  #From protocol 2
    "acutebronchitis": codelists.acute_bronchitis_control_codelist,
    "conjunctivitisallergic": codelists.conjunctivitis_allergic_control_codelist,
    "vulvovaginalcandidiasis": codelists.vulvovaginal_candidiasis_control_codelist,
}
all_gp_pf_conditions_codes = gp_pf_conditions
# Later, when medications for controls are available:
# all_gp_pf_conditions_codes = {
#     **gp_pf_conditions,
#     **control_conditions_gp_pf_codes,
# }
# Any GP/PF condition consultation
gp_pf_condition_codes = []
for codes in all_gp_pf_conditions_codes.values():
    gp_pf_condition_codes += codes

gp_pf_condition_events = gp_pf_selected_events.where(gp_pf_selected_events.snomedct_code.is_in(gp_pf_condition_codes))
gp_pf_consultation_ids = gp_pf_condition_events.consultation_id
selected_gp_pf_events = select_events_by_consultation_id(gp_pf_selected_events, gp_pf_consultation_ids)

dataset.gp_pf_consultation_general = gp_pf_consultation_ids.count_distinct_for_patient()
# 0.1 Consultation counts
for name, codes in gp_pf_conditions.items():
    count_consultation, count_date = has_event_count(selected_gp_pf_events, codes)
    setattr(dataset, f"numerator_gp_pf_consultation_{name}", count_consultation)
    setattr(dataset, f"numerator_gp_pf_date_{name}", count_date)

# 0.2 Medication counts
for name, condition_codes in gp_pf_conditions.items():
    condition_events = select_events_from_codelist(selected_gp_pf_events, condition_codes)
    condition_ids = condition_events.consultation_id
    condition_consultation_events = select_events_by_consultation_id(selected_gp_pf_events, condition_ids)

    count_medication, count_medication_date = has_event_count(condition_consultation_events,codelists.pharmacy_first_condition_specific_medications_dict[name],)

    setattr(dataset, f"numerator_gp_pf_medication_{name}", count_medication)
    setattr(dataset, f"numerator_gp_pf_medication_date_{name}", count_medication_date)

    # 0.3 First- and second-line medications
    for medication_name, medication_codes in codelists.pf_first_secondline_medications[name].items():
        count_medication, count_medication_date = has_event_count(condition_consultation_events, medication_codes)
        setattr(dataset, f"numerator_gp_pf_{medication_name}_{name}", count_medication)
        setattr(dataset, f"numerator_gp_pf_{medication_name}_date_{name}", count_medication_date)
"""
######################################################## 1.Community Pharmacies PF-->P4
'''
This section counts the number of PF consultations and medication for each condition.
!!!!!!!---> HERE,WE USE THE UNIQUE CODE FOR A PF CONDITIONS AS IT IS MENTIONNED IN PHARMACY FIRST GITHUB SAMPLE CODES . ie THAT IN CP,PHARMACYST SEE A SINGLE CODE FOR A CONDITION WHILE A  GP  CAN SEE MULTIPLES CODES FOR THE SAME CONDITION
Outputs:
- pf_consultation_general: consultation count where their clinical events have any of the three general PF codes 
- pf_consultation_general_butno_condition: consultation count where their clinical events have any of the three general PF codes BUT no PF condition codes
- numerator_pf_consultation_{name}: number of PF consultations for a specific PF condition
- numerator_pf_date_{name}: Distinct consultation dates:number of PF consultation episodes for a specific PF condition (consultations occurring within the same day are grouped into a single episode)
 
 *P4
- numerator_pf_medication_{name}:number of PF medication for a specific PF condition
- numerator_pf_medication_date_{name}:number of PF medication episodes for a specific PF condition (medications occurring within the same day are grouped into a single episode)
- numerator_pf_{medication_name}_{name}": number of specific PF medication (First or 2nd line ) for a specific  PF condition
- numerator_pf_{medication_name}_date_{name}": number of specific PF medication (First or 2nd line ) episodes for a specific  PF condition
-Lagged outputs:
-numerator_pf_medication_{name}_lagged: Number of PF lagged  medication 
''' 
# 1.A. No lag

selected_events = select_events_between(clinical_events, start_date, index_date)   # 1.This keeps only clinical events occurring between the two dates : airadukunda 
pf_consultation_events = select_events_from_codelist(selected_events, codelists.pf_consultation_events_dict["pf_consultation_services_combined"])  # 2.This finds  all Pharmacy First consultations( remember what pf_consultation_events_dict means in codelists.py : airadukunda
#PF denominator
has_pf_consultation = pf_consultation_events.exists_for_patient()
#Define the denominator as the number of patients registered
registration = practice_registrations.for_patient_on(index_date)
pf_denominator = (
    registration.exists_for_patient()
    & patients.sex.is_in(["male", "female"])
    & has_pf_consultation
)
# 'pf_ids' is a set of consultation ids where their clinical events have any of the three general PF codes
pf_ids = pf_consultation_events.consultation_id          # 3.this extract consultation IDs : airadukunda
selected_pf_id_events = select_events_by_consultation_id(selected_events, pf_ids) #4. this retrieve all events from those consultations (pf_ids) : airadukunda

# dataset.has_pf_consultation = pf_consultation_events.exists_for_patient()

dataset.pf_consultation_general = pf_consultation_events.consultation_id.count_distinct_for_patient()   # 5.this  counts all PF consultations : airadukunda

# Pharmacy First condition codelists

# pf_conditions_pf_codes (For GP pf codes, we use the codelist developed for the protocole 4 instead codelist from PF codes sample): airadukunda
# No controls here as we only have codes for PF condtions in community pharmacies
cp_all_conditions_codelist = (
    codelists.uti_code +
    codelists.sinusitis_code +
    codelists.insectbite_code +
    codelists.otitismedia_code +
    codelists.sorethroat_code +
    codelists.shingles_code +
    codelists.impetigo_code 
)

pf_conditions_pf_codes = {                               # 6.This define PF condition codes (seven clinical pathways of Pharmacy First), ------> Here we can use codelists developed for the protocole 4 instead
    "uti": codelists.uti_code,
    "sinusitis": codelists.sinusitis_code,
    "insectbite": codelists.insectbite_code,
    "otitismedia": codelists.otitismedia_code,
    "sorethroat": codelists.sorethroat_code,
    "shingles": codelists.shingles_code,
    "impetigo": codelists.impetigo_code,
    "all_conditions": cp_all_conditions_codelist,
}

# a set of codes for any PF condition
pf_conditions_pf_code_set = []
# one big list of all PF condition codes .This becomes:"Any Pharmacy First condition.": airadukunda
for codes in pf_conditions_pf_codes.values():
    pf_conditions_pf_code_set += codes

# events with both general PF codes and PF condition codes
pf_condition_events = selected_pf_id_events.where(selected_pf_id_events.snomedct_code.is_in(pf_conditions_pf_code_set)) #8.This will find PF consultations with a PF condition (i.e events where consultation is Pharmacy First AND a PF condition code exists)

# consultation IDs for these events
pf_condition_consultation_ids = pf_condition_events.consultation_id                                                     #9.Extract consultation IDs with conditions

# select PF consultation events (those with general PF codes) that the consultation id is not in the set of consultation ids with condition codes
pf_consultations_general_butno_condition_events = pf_consultation_events.where(                                         #10.Find PF consultations with NO condition code (this will keep PF consultations whose consultation ID is NOT linked to a PF condition code).
    ~pf_consultation_events.consultation_id.is_in(pf_condition_consultation_ids)
)

# count number of consultations from the above event selection
dataset.pf_consultation_general_butno_condition = (
    pf_consultations_general_butno_condition_events.consultation_id.count_distinct_for_patient()
)                                                                                                                       #11.Count those consultations: Number of PF consultations where a general PF code exists but no PF pathway condition code exists.
# Loop and Runs for: uti,sinusitis,insectbite, otitismedia,sorethroat,shingles,impetigo :   airadukunda
for name, codes in pf_conditions_pf_codes.items():                                                                      #12. Count consultations and episodes for each condition

    # count consultations and episodes (consultations occurring within the same day are grouped into a single episode)
    count_pf_consultation, count_pf_date = has_event_count(selected_pf_id_events, codes)                                #13.Count consultations and episodes

    setattr(dataset, f"numerator_pf_consultation_{name}", count_pf_consultation)                                       #14.Store results:"dataset.numerator_pf_consultation_uti" for example
    setattr(dataset, f"numerator_pf_date_{name}", count_pf_date)                                                       #14.Store results:"dataset.numerator_pf_date_uti" for example

#----Medication : airadukunda-----------------------------------------------------------------------------------------------------------------------------------------------------
# 1. Numerators
for name, condition_codes in pf_conditions_pf_codes.items():

    #1. PF consultations for condition
    condition_events = select_events_from_codelist(selected_pf_id_events, condition_codes)
    condition_ids = condition_events.consultation_id

    # All events from those consultations
    condition_consultation_events = select_events_by_consultation_id(selected_pf_id_events, condition_ids)
    # 2. Any condition-specific medication
    count_medication, count_medication_date = has_event_count(condition_consultation_events, codelists.pharmacy_first_condition_specific_medications_dict[name])

    setattr(dataset, f"numerator_pf_medication_{name}", count_medication)
    setattr(dataset, f"numerator_pf_medication_date_{name}", count_medication_date)

    # 3.First- and second-line medications 
    for medication_name, medication_codes in codelists.pf_first_secondline_medications[name].items():

        count_medication, count_medication_date = has_event_count(condition_consultation_events, medication_codes)

        setattr(dataset, f"numerator_pf_{medication_name}_{name}", count_medication)
        setattr(dataset, f"numerator_pf_{medication_name}_date_{name}", count_medication_date)
# 1.B.One week lagged medication
'''
Main changes made:
1. Conditions are still extracted using the original monthly window
2. Medications are now extracted using an lagged window that runs
   from start_date -> index_date + 7 days ("monthly + 7 days lag").
   This means a medication linked to the same consultation_id as a
   condition can be picked up even if it was recorded up to 7 days
   after the monthly index_date.
3. All medication-related output variable names now have "_lag"
   appended, so they don't collide with the original (non-lagged)
   medications.

# --------------------------------------------------------------------------------------------------------------
# Here, we build an extended event set that covers the monthly window + 7 days,
# used ONLY for matching medications (conditions still use the original monthly-only `selected_pf_id_events`).
# --------------------------------------------------------------------------------------------------------------
'''
lag_end_date = index_date + days(7)
selected_events_lag = select_events_between(clinical_events, start_date, lag_end_date)

pf_consultation_events_lag = select_events_from_codelist(
    selected_events_lag,
    codelists.pf_consultation_events_dict["pf_consultation_services_combined"],
)
pf_ids_lag = pf_consultation_events_lag.consultation_id
selected_pf_id_events_lag = select_events_by_consultation_id(selected_events_lag, pf_ids_lag)
# -------------------------------------------------------------------------------------------
#  Medications: condition matched monthly, medication matched monthly+7days
# ------------------------------------------------------------------------------------------
#-----1.B.1.Lag for uti only----------------------------------------------------------------- 

name = "uti"  # <-- restrict to UTI only
condition_codes = pf_conditions_pf_codes[name]
# 1. PF consultations for condition -- MONTHLY window (unchanged)
condition_events = select_events_from_codelist(selected_pf_id_events, condition_codes)
condition_ids = condition_events.consultation_id
# 2. All events from those SAME consultation ids, but pulled from the
#    LAGGED event set (monthly + 7 days), so medications recorded up
#    to 7 days after index_date are still captured.
condition_consultation_events_lag = select_events_by_consultation_id(
    selected_pf_id_events_lag, condition_ids
)
# 3. Any condition-specific medication (lagged)
count_medication_lag, count_medication_date_lag = has_event_count(
    condition_consultation_events_lag,
    codelists.pharmacy_first_condition_specific_medications_dict[name],
)

setattr(dataset, f"numerator_pf_medication_{name}_lag", count_medication_lag)
setattr(dataset, f"numerator_pf_medication_date_{name}_lag", count_medication_date_lag)

# 4. First- and second-line medications (lagged)
for medication_name, medication_codes in codelists.pf_first_secondline_medications[name].items():
    count_medication_lag, count_medication_date_lag = has_event_count(
        condition_consultation_events_lag, medication_codes
    )
    setattr(dataset, f"numerator_pf_{medication_name}_{name}_lag", count_medication_lag)
    setattr(dataset, f"numerator_pf_{medication_name}_date_{name}_lag", count_medication_date_lag)

'''
# -------1.B.2.Lag for each condition-------------------------------------

for name, condition_codes in pf_conditions_pf_codes.items():
    # 1. PF consultations for condition -- MONTHLY window (unchanged)
    condition_events = select_events_from_codelist(selected_pf_id_events, condition_codes)
    condition_ids = condition_events.consultation_id
    # 2. All events from those SAME consultation ids, but pulled from the
    #    LAGGED event set (monthly + 7 days), so medications recorded up
    #    to 7 days after index_date are still captured.
    condition_consultation_events_lag = select_events_by_consultation_id(
        selected_pf_id_events_lag, condition_ids
    )
   # 3. Any condition-specific medication (lagged)
    count_medication_lag, count_medication_date_lag = has_event_count(
        condition_consultation_events_lag,
        codelists.pharmacy_first_condition_specific_medications_dict[name],
    )

    setattr(dataset, f"numerator_pf_medication_{name}_lag", count_medication_lag)
    setattr(dataset, f"numerator_pf_medication_date_{name}_lag", count_medication_date_lag)

    # 4. First- and second-line medications (lagged)
    for medication_name, medication_codes in codelists.pf_first_secondline_medications[name].items():

        count_medication_lag, count_medication_date_lag = has_event_count(
            condition_consultation_events_lag, medication_codes
        )
        setattr(dataset, f"numerator_pf_{medication_name}_{name}_lag", count_medication_lag)
        setattr(dataset, f"numerator_pf_{medication_name}_date_{name}_lag", count_medication_date_lag)
'''
######################################################## 2.GENERAL PRACTICE 
'''
This section counts the number of GP consultations and GP prescribitions  for PF-related conditions and control conditions, explicitly excluding consultations identified as PF consultations using general PF service codes.

Key logic:
- pf_ids' represents consultation IDs where at least one event contains a general PF service code.
 
1. 'gp_events_clean' is derived by excluding all events belonging to consultations in 'pf_ids'. 
- This ensures that GP consultation counts do not overlap with PF consultation counts.
2. Identify PF-related conditions in managed in GP using the condition-specific SNOMED codelists (e.g. UTI, sinusitis)
3. Consultations are counted using distinct consultation IDs per patient. 
- For testing purpose, episodes are defined by grouping events occurring within a 1-day window, so multiple events on the same day are treated as a single episode. 

Outputs:
- numerator_gp_consultation_{name}: number of GP consultations for a specific PF condition
- numerator_gp_date_{name}: number of GP consultation dates for a specific PF condition (consultations occurring within the same day are grouped into a single episode)

*P4
- numerator_gp_medication_{name}": number of GP medications for a specific PF condition and controls 
- numerator_gp_medication_date_{name}": number of GP medication dates for a specific PF condition and controls  (medication occurring within the same day are grouped into a single episode)
- numerator_gp_{medication_name}_{name} :number of GP medications (first or second lines) for a specific PF condition and controls 
- numerator_gp_{medication_name}_date_{name}:  number of GP medication  dates (first or second lines) for a specific PF condition and controls  (medication occurring within the same day are grouped into a single episode)

'''
# 2.A.No lag 

gp_events_clean = selected_events.where(                           # This line is removing all events that occurred in Pharmacy First consultations, leaving only events from non-Pharmacy First consultations (e.g., GP consultations, ...).
    ~selected_events.consultation_id.is_in(pf_ids)
)
#PF denominator
has_gp_consultation = gp_events_clean.exists_for_patient()
dataset.has_gp_consultation = gp_events_clean.exists_for_patient().as_int()
# GP general consultations
dataset.gp_consultation_general = (
    gp_events_clean.consultation_id.count_distinct_for_patient()
)
#Define the denominator as the number of patients registered
gp_denominator = (
    registration.exists_for_patient()
    & patients.sex.is_in(["male", "female"])
    & has_gp_consultation
)

#Codelist for P2 are removed  and replaced by P4 codelists below:
# These codes are GP codelist (for P4) :one condition can be recoreded under different names and  codes): better to  consider the consultation ids  
# pf_conditions_gp_codes:  conditions + their controls ;we make sure their medication to be there

gp_all_conditions = (
    codelists.uti_codelist +
    codelists.sinusitis_codelist +
    codelists.infected_insect_bites_codelist +
    codelists.otitis_media_codelist +
    codelists.sore_throat_codelist +
    codelists.shingles_codelist +
    codelists.impetigo_codelist
)

pf_conditions_gp_codes = {                                        
    "uti": codelists.uti_codelist,    
    "sinusitis": codelists.sinusitis_codelist,
    "insectbite": codelists.infected_insect_bites_codelist,
    "otitismedia": codelists.otitis_media_codelist,
    "sorethroat": codelists.sore_throat_codelist,
    "shingles": codelists.shingles_codelist,
    "impetigo": codelists.impetigo_codelist,
    "all_conditions": gp_all_conditions,
}

# Backpain removed to be added together with P4 controls
# Controls for P4:  # We added  controls as for our analysis to conducte Compartive XTITSA
#----> we need to make sure that medication for controls is there 

control_conditions_gp_codes = {
    #"lowerbackpain": codelists.gp_snomed_codelist_lower_back_pain,
    "acutebronchitis_control": codelists.acute_bronchitis_control_codelist,
    "conjunctivitisallergic_control": codelists.conjunctivitis_allergic_control_codelist,
    "vulvovaginalcandidiasis_control": codelists.vulvovaginal_candidiasis_control_codelist,
}
#all_conditions_gp_codes = pf_conditions_gp_codes
all_conditions_gp_codes = pf_conditions_gp_codes|control_conditions_gp_codes
"""
all_conditions_gp_codes = { 
  **pf_conditions_gp_codes,
   **control_conditions_gp_codes, #first , we will need to add medication for controls 
}
"""
# for name, codes in pf_conditions_gp_codes.items():
for name, codes in all_conditions_gp_codes.items():
    count_gp_consultation, count_gp_date = has_event_count(gp_events_clean, codes)
    setattr(dataset, f"numerator_gp_consultation_{name}", count_gp_consultation)
    setattr(dataset, f"numerator_gp_date_{name}", count_gp_date)

# ---- GP Medication : airadukunda ------------------------------------------
# 2. Numerators 
for name, condition_codes in all_conditions_gp_codes.items():

    # GP consultations for PF condition
    condition_events = select_events_from_codelist(gp_events_clean,condition_codes,)
    condition_ids = condition_events.consultation_id
    # All events from those consultations
    condition_consultation_events = select_events_by_consultation_id(gp_events_clean,condition_ids,)
    # Any condition-specific medication
    count_medication, count_medication_date = has_event_count(condition_consultation_events,codelists.pharmacy_first_condition_specific_medications_dict[name],)
    setattr(dataset,f"numerator_gp_medication_{name}",count_medication,)
    setattr(dataset,f"numerator_gp_medication_date_{name}",count_medication_date,)
    
    # First- and second-line medications
    for medication_name, medication_codes in (codelists.pf_first_secondline_medications[name].items()):
        count_medication, count_medication_date = has_event_count(condition_consultation_events, medication_codes,)
        setattr(dataset,f"numerator_gp_{medication_name}_{name}",count_medication,)
        setattr(dataset,f"numerator_gp_{medication_name}_date_{name}",count_medication_date, )

# 2.B. One week laggged medication in GP practice
'''
Main changes made:
1. GP conditions are still counted using the ORIGINAL monthly window
   -(gp_events_clean, built from selected_events -> start_date..index_date),unchanged.
2. GP MEDICATIONS are now matched using an EXTENDED window
   -(start_date -> index_date + 7 days), built here as `gp_events_clean_lag`,
   -which reuses `selected_events_lag` / `pf_ids_lag` used in the PF section
   -(so PF consultations are still excluded, just from the lagged set).
3. All medication-related GP output variables now have "_lag" appended
'''
# --------------------------------------------------------------------------------
gp_events_clean_lag = selected_events_lag.where(
    ~selected_events_lag.consultation_id.is_in(pf_ids_lag)
)
#----2.B.1. One week laged for uti only in General practice------------------------------------
name = "uti"  # <-- restrict to UTI only
condition_codes = all_conditions_gp_codes[name]
# 1. GP consultations for condition -- MONTHLY window (unchanged)
condition_events = select_events_from_codelist(gp_events_clean, condition_codes)
condition_ids = condition_events.consultation_id

# 2. All events from those SAME consultation ids, but pulled from the
#    clean GP event set (monthly + 7 days).
condition_consultation_events_lag = select_events_by_consultation_id(
    gp_events_clean_lag, condition_ids
)

# 3. Any condition-specific medication (lagged)
count_medication_lag, count_medication_date_lag = has_event_count(
    condition_consultation_events_lag,
    codelists.pharmacy_first_condition_specific_medications_dict[name],
)

setattr(dataset, f"numerator_gp_medication_{name}_lag", count_medication_lag)
setattr(dataset, f"numerator_gp_medication_date_{name}_lag", count_medication_date_lag)

# 4. First- and second-line medications (lagged)
for medication_name, medication_codes in codelists.pf_first_secondline_medications[name].items():
    count_medication_lag, count_medication_date_lag = has_event_count(
        condition_consultation_events_lag, medication_codes
    )

    setattr(dataset, f"numerator_gp_{medication_name}_{name}_lag", count_medication_lag)
    setattr(dataset, f"numerator_gp_{medication_name}_date_{name}_lag", count_medication_date_lag)

""" 
#2.B.2.One week lagged medication of each condition
# ---------------------------------------------------------------------------------
# GP Medications: condition matched monthly, medication matched monthly+7days
# ---------------------------------------------------------------------
for name, condition_codes in all_conditions_gp_codes.items():
    # 1. GP consultations for condition -- MONTHLY window (unchanged)
    condition_events = select_events_from_codelist(gp_events_clean, condition_codes)
    condition_ids = condition_events.consultation_id
    # 2. All events from those SAME consultation ids, but pulled from the
    #    clean GP event set (monthly + 7 days).
    condition_consultation_events_lag = select_events_by_consultation_id(
        gp_events_clean_lag, condition_ids
    )
    # 3. Any condition-specific medication (lagged)
    count_medication_lag, count_medication_date_lag = has_event_count(
        condition_consultation_events_lag,
        codelists.pharmacy_first_condition_specific_medications_dict[name],
    )

    setattr(dataset, f"numerator_gp_medication_{name}_lag", count_medication_lag)
    setattr(dataset, f"numerator_gp_medication_date_{name}_lag", count_medication_date_lag)

    # 4. First- and second-line medications (lagged)
    for medication_name, medication_codes in codelists.pf_first_secondline_medications[name].items():

        count_medication_lag, count_medication_date_lag = has_event_count(
            condition_consultation_events_lag, medication_codes
        )

        setattr(dataset, f"numerator_gp_{medication_name}_{name}_lag", count_medication_lag)
        setattr(dataset, f"numerator_gp_{medication_name}_date_{name}_lag", count_medication_date_lag)
"""
########################################################
'''
This section counts the number of GP consultations for PF-related conditions by consultation mode (excluding consultations with PF service codes)

Key logic :
- 'gp_events_clean' already excludes all consultations with PF service codes (pf_ids).

1. 'pf_conditions_gp_code_set' is creased, including all GP used SNOMED codes for the seven conditions 
2. events in 'gp_events_clean' are filtered using the combined code set to identify condition-related events.
3. consultation IDs are then extracted from events in step 2. This set of IDs represents the condition-related consultations without any PF service codes.
4. retrieve all events within the selected consultation IDs 
5. consultation mode is classified using specific codelists:
5.1 three sets of events are identified for each consultation type: face-to-face, online, and telephone
5.2 consultation IDs are extracted for each type/event set
5.3 a hierarchical assignment is applied:
- face-to-face takes precedence
- online excludes consultations already classified as face-to-face
- telephone excludes consultations classified as face-to-face or online
- remaining consultations are classified as 'othermode'
- all counts are based on distinct consultation IDs per patient.

Outputs:
- gp_pf_consultation_f2f
- gp_pf_consultation_online
- gp_pf_consultation_f2f_telephone
- gp_pf_consultation_othermode
'''
pf_conditions_gp_code_set = []
for codes in pf_conditions_gp_codes.values():
    pf_conditions_gp_code_set += codes

gp_pf_condition_events = gp_events_clean.where(gp_events_clean.snomedct_code.is_in(pf_conditions_gp_code_set))
gp_pf_condition_ids = gp_pf_condition_events.consultation_id
gp_pf_condition_all_events = select_events_by_consultation_id(gp_events_clean,gp_pf_condition_ids)
gp_pf_f2f_type_events = select_events_from_codelist(
    gp_pf_condition_all_events,
    codelists.gp_codelist_consultation_f2f
)
gp_pf_online_type_events = select_events_from_codelist(
    gp_pf_condition_all_events,
    codelists.gp_codelist_consultation_online
)
gp_pf_telephone_type_events = select_events_from_codelist(
    gp_pf_condition_all_events,
    codelists.gp_codelist_consultation_telephone
)
gp_pf_f2f_ids = gp_pf_f2f_type_events.consultation_id
gp_pf_online_ids = gp_pf_online_type_events.consultation_id
gp_pf_telephone_ids = gp_pf_telephone_type_events.consultation_id

dataset.gp_pf_consultation_f2f = (
    gp_pf_f2f_ids.count_distinct_for_patient()
)

dataset.gp_pf_consultation_online = (
    gp_pf_online_type_events.where(
        ~gp_pf_online_type_events.consultation_id.is_in(gp_pf_f2f_ids)
    ).consultation_id.count_distinct_for_patient()
)

dataset.gp_pf_consultation_telephone = (
    gp_pf_telephone_type_events.where(
        ~gp_pf_telephone_type_events.consultation_id.is_in(gp_pf_f2f_ids)
        & ~gp_pf_telephone_type_events.consultation_id.is_in(gp_pf_online_ids)
    ).consultation_id.count_distinct_for_patient()
)

dataset.gp_pf_consultation_othermode = (
    gp_pf_condition_all_events.where(
        ~gp_pf_condition_all_events.consultation_id.is_in(gp_pf_f2f_ids)
        & ~gp_pf_condition_all_events.consultation_id.is_in(gp_pf_online_ids)
        & ~gp_pf_condition_all_events.consultation_id.is_in(gp_pf_telephone_ids)
    ).consultation_id.count_distinct_for_patient()
)

########################################################
'''
This section repeats the above logic to count GP consultations by consultation mode,
but only for control conditions rather than PF-conditions

Outputs:
- gp_control_consultation_f2f
- gp_control_consultation_online
- gp_control_consultation_f2f_telephone
- gp_control_consultation_othermode
'''
control_conditions_gp_code_set = []
for codes in control_conditions_gp_codes.values():
    control_conditions_gp_code_set += codes

gp_control_condition_events = gp_events_clean.where(
    gp_events_clean.snomedct_code.is_in(control_conditions_gp_code_set)
)
gp_control_condition_ids = gp_control_condition_events.consultation_id
gp_control_condition_all_events = select_events_by_consultation_id(
    gp_events_clean,
    gp_control_condition_ids
)

gp_control_f2f_type_events = select_events_from_codelist(
    gp_control_condition_all_events,
    codelists.gp_codelist_consultation_f2f
)
gp_control_online_type_events = select_events_from_codelist(
    gp_control_condition_all_events,
    codelists.gp_codelist_consultation_online
)
gp_control_telephone_type_events = select_events_from_codelist(
    gp_control_condition_all_events,
    codelists.gp_codelist_consultation_telephone
)

gp_control_f2f_ids = gp_control_f2f_type_events.consultation_id
gp_control_online_ids = gp_control_online_type_events.consultation_id
gp_control_telephone_ids = gp_control_telephone_type_events.consultation_id

dataset.gp_control_consultation_f2f = (
    gp_control_f2f_ids.count_distinct_for_patient()
)

dataset.gp_control_consultation_online = (
    gp_control_online_type_events.where(
        ~gp_control_online_type_events.consultation_id.is_in(gp_control_f2f_ids)
    ).consultation_id.count_distinct_for_patient()
)

dataset.gp_control_consultation_telephone = (
    gp_control_telephone_type_events.where(
        ~gp_control_telephone_type_events.consultation_id.is_in(gp_control_f2f_ids)
        & ~gp_control_telephone_type_events.consultation_id.is_in(gp_control_online_ids)
    ).consultation_id.count_distinct_for_patient()
)

dataset.gp_control_consultation_othermode = (
    gp_control_condition_all_events.where(
        ~gp_control_condition_all_events.consultation_id.is_in(gp_control_f2f_ids)
        & ~gp_control_condition_all_events.consultation_id.is_in(gp_control_online_ids)
        & ~gp_control_condition_all_events.consultation_id.is_in(gp_control_telephone_ids)
    ).consultation_id.count_distinct_for_patient()
)

########################################################
'''
This section counts the number of GP consultations for each PF-related conditions and control conditions by consultation mode (excluding consultations with PF service codes)

Outputs:
- gp_consultation_<name>_f2f
- gp_consultation_<name>_online
- gp_consultation_<name>_telephone
- gp_consultation_<name>_othermode
'''

# for name, codes in pf_conditions_gp_codes.items():
for name, codes in all_conditions_gp_codes.items():

    # condition-specific events -> consultation IDs
    condition_events = gp_events_clean.where(gp_events_clean.snomedct_code.is_in(codes))
    condition_ids = condition_events.consultation_id
    # retrieve all events within these consultations
    condition_all_events = select_events_by_consultation_id(gp_events_clean,condition_ids)

    # assign consultation mode
    f2f_events = select_events_from_codelist(condition_all_events,codelists.gp_codelist_consultation_f2f)
    online_events = select_events_from_codelist(condition_all_events,codelists.gp_codelist_consultation_online)
    telephone_events = select_events_from_codelist(condition_all_events,codelists.gp_codelist_consultation_telephone)
    f2f_ids = f2f_events.consultation_id
    online_ids = online_events.consultation_id
    telephone_ids = telephone_events.consultation_id

    setattr(dataset,f"gp_consultation_{name}_f2f",f2f_ids.count_distinct_for_patient())
    setattr(dataset,f"gp_consultation_{name}_online",
        online_events.where(
            ~online_events.consultation_id.is_in(f2f_ids)
        ).consultation_id.count_distinct_for_patient()
    )
    setattr(dataset,f"gp_consultation_{name}_telephone",
        telephone_events.where(
            ~telephone_events.consultation_id.is_in(f2f_ids)
            & ~telephone_events.consultation_id.is_in(online_ids)
        ).consultation_id.count_distinct_for_patient()
    )
    setattr(dataset,f"gp_consultation_{name}_othermode",
        condition_all_events.where(
            ~condition_all_events.consultation_id.is_in(f2f_ids)
            & ~condition_all_events.consultation_id.is_in(online_ids)
            & ~condition_all_events.consultation_id.is_in(telephone_ids)
        ).consultation_id.count_distinct_for_patient()
    )

########################################################
"""
Clinical variables for eligible population denominator:
- pregnant_this_month
- bullous_impetigo_this_month
- recurrent_impetigo_this_year
- catheter_status
- recurrent_uti
"""

from analysis.pf_variable_library import check_code_in_time_window, check_recurrent_status
# -- pregnancy_status - naive version
# pregnant_this_month = check_code_in_time_window(index_date-months(1),index_date, clinical_events, codelists.gp_snomed_codelist_pregnancy)
# dataset.pregnant_this_month = pregnant_this_month
# -- pregancy_status developed by Helen
# look back for recent end-of-pregnancy codes -- assume no longer pregnant if in last 12 weeks
dataset.pregnancy_end_recent = clinical_events.where(
    clinical_events.snomedct_code.is_in(codelists.gp_snomed_codelist_end_pregnancy) &
    clinical_events.date.is_on_or_between(start_date - weeks(32), start_date - days(1))
    ).sort_by(clinical_events.date).last_for_patient().date
# look ahead 40 weeks for end-of-pregnancy codes
dataset.pregnancy_end = clinical_events.where(
    clinical_events.snomedct_code.is_in(codelists.gp_snomed_codelist_end_pregnancy) &
    clinical_events.date.is_on_or_between(start_date, start_date + weeks(40))
    ).sort_by(clinical_events.date).first_for_patient().date
# estimated date of delivery (EDD) - very recent or in future to estimate the known start of pregnancy
dataset.pregnancy_edd = clinical_events.where(
    clinical_events.date.is_on_or_between(start_date - weeks(2), start_date + weeks(34)) &
    clinical_events.snomedct_code.is_in(codelists.gp_snomed_codelist_pregnancy_edd)
    ).sort_by(clinical_events.date).first_for_patient().date
# recent "pregnant" codes - this is to be used where no delivery or EDD recorded
dataset.pregnancy_code = clinical_events.where(
    clinical_events.snomedct_code.is_in(codelists.gp_snomed_codelist_pregnancy) &
    clinical_events.date.is_on_or_between(start_date - weeks(12), start_date + weeks(4))
    ).sort_by(clinical_events.date).first_for_patient().date
# combine criteria to create a pregnancy status for the current month:
dataset.pregnant = case(
    # recent delivery -> not pregnant now:
    when(dataset.pregnancy_end_recent.is_on_or_after(start_date - weeks(12))).then("0-R"),
    # EDD in month or next 8 months, not preceeded by an end-of-pregnancy
    when(dataset.pregnancy_edd.is_not_null() 
        # check that the pregnancy linked to the EDD did not end very early,
        # i.e prior to the last 12 weeks which is already captured above
         & (dataset.pregnancy_end_recent.is_null() # no past delivery captured
            | ~dataset.pregnancy_end_recent.is_on_or_between(dataset.pregnancy_edd-weeks(28),dataset.pregnancy_edd+weeks(3))
            )).then("P-EDD"),
    # end of pregnancy in month or next 2 months - currently pregnant:
    when(dataset.pregnancy_end.is_on_or_before(start_date + weeks(12))).then("P-E"),
    # recent pregnancy code
    when(dataset.pregnancy_code.is_not_null()).then("P"),
    otherwise="0",)
pregnant_this_month = dataset.pregnant.is_in(("P-E", "P-EDD", "P"))
dataset.pregnant_this_month = pregnant_this_month

# bullous_impetigo during the specific month
bullous_impetigo_this_month = check_code_in_time_window(index_date-months(1),index_date,clinical_events,codelists.gp_snomed_codelist_bullous_impetigo)
dataset.bullous_impetigo_this_month = bullous_impetigo_this_month

# recurrent_impetigo: (defined as 2 or more episodes in the same year) 
# an episode is defined as a 4 week period, so any codes within this time are considered to be part of the same episode.
# >= two 4-week-separated episodes
recurrent_impetigo_this_year = check_recurrent_status(index_date, clinical_events, codelists.gp_snomed_codelist_impetigo, 
                                                      lookback_months=12, gap_weeks=4, min_episodes=2)
dataset.recurrent_impetigo_this_year = recurrent_impetigo_this_year

# catheter_status: excluding patients who clearly have a catheter, and for following 12 months after code is included
catheter_status = check_code_in_time_window(index_date - months(12),index_date,clinical_events,codelists.gp_snomed_codelist_urinary_catheter)
dataset.catheter_status = catheter_status

# recurrent_uti: (2 episodes in last 6 months, or 3 episodes in last 12 months) an episode is defined as a 4 week period, so any codes within this time are considered to be part of the same episode.
# recurrent_uti_6m = (age < 0)
# recurrent_uti_12m = (age < 0)
recurrent_uti_6m = check_recurrent_status(
    index_date, clinical_events, codelists.gp_snomed_codelist_uti,
    lookback_months=6, gap_weeks=4,min_episodes=2
)
recurrent_uti_12m = check_recurrent_status(
    index_date, clinical_events, codelists.gp_snomed_codelist_uti,
    lookback_months=12, gap_weeks=4, min_episodes=3
)
recurrent_uti = recurrent_uti_6m | recurrent_uti_12m
dataset.recurrent_uti_6m = recurrent_uti_6m
dataset.recurrent_uti_12m = recurrent_uti_12m
dataset.recurrent_uti = recurrent_uti

########################################################
"""
Eligibility/clinical characteristics flag for study population denominator:
- include_patient_otitis_media
- include_patient_sinusitis
- include_patient_sore_throat
- include_patient_insect_bites
- include_patient_shingles
- include_patient_impetigo
- include_patient_uti
- include_patient_overall_eligible
"""
female = patients.sex.is_in(["female"])

# Condition: acute otitis media
# - inclusion: children aged 1 to 17 years
# - exclusion: none
include_patient_otitis_media = (age >= 1) & (age <= 17) 
dataset.include_patient_otitis_media = include_patient_otitis_media

# Condition: acute sinusitis
# - inclusion: age >= 12
# - exclusion: none
include_patient_sinusitis = (age >= 12)
dataset.include_patient_sinusitis = include_patient_sinusitis

# Condition: acute sore throat
# - inclusion: age >= 5
# - exclusion: pregnant female under 16s
age_eligible_sore_throat = (age >= 5)
exclusion_sore_throat = pregnant_this_month & (age < 16) & (female)
include_patient_sore_throat = (age_eligible_sore_throat & ~exclusion_sore_throat)
dataset.include_patient_sore_throat = include_patient_sore_throat

# Condition: infected insect bites
# - inclusion: age >= 1
# - exclusion: pregnant female under 16s
age_eligible_insect_bites = (age >= 1)
exclusion_insect_bites = pregnant_this_month & (age < 16) & (female)
include_patient_insect_bites = (age_eligible_insect_bites & ~exclusion_insect_bites)
dataset.include_patient_insect_bites = include_patient_insect_bites

# Condition: shingles
# - inclusion: age >= 18
# - exclusion: pregnant female
age_eligible_shingles = (age >= 18)
exclusion_shingles = pregnant_this_month & (female)
include_patient_shingles = (age_eligible_shingles & ~exclusion_shingles)
dataset.include_patient_shingles = include_patient_shingles

# Condition: impetigo
# - inclusion: age >= 1
# - exclusion: 
# - - bullous impetigo, 
# - - recurrent impetigo (defined as 2 or more episodes in the same year), 
# - - pregnant female under 16 years
impetigo_age_eligible = (age >= 1)
impetigo_exclusion = (bullous_impetigo_this_month | recurrent_impetigo_this_year | (pregnant_this_month & (age < 16) & female))
include_patient_impetigo = (impetigo_age_eligible & ~impetigo_exclusion)
dataset.include_patient_impetigo = include_patient_impetigo

# Condition: Uncomplicated UTI
# - inclusion: women aged 16 to 64 years
# - exclusion: 
# - - pregnant female
# - - urinary catheter
# - - recurrent UTI: 2 episodes in last 6 months, or 3 episodes in last 12 months
uuti_eligible = (age >= 16) & (age <= 64) & female
uuti_exclusion = (pregnant_this_month | catheter_status | recurrent_uti)
include_patient_uuti = (uuti_eligible & ~uuti_exclusion)
dataset.include_patient_uuti = include_patient_uuti

# include_patient_overall_eligible
include_patient_overall_eligible = (include_patient_otitis_media|include_patient_sinusitis
                                  |include_patient_sore_throat|include_patient_insect_bites
                                  |include_patient_shingles|include_patient_impetigo|include_patient_uuti)
dataset.include_patient_overall_eligible = include_patient_overall_eligible
#P4

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

dataset.pf_eligible_population = pf_eligible_population

#
pop= (
    dataset.alive
    & dataset.registered_start
    & dataset.registered_index
    & (dataset.age <= 120)
)
dataset.pop = pop


######################################################## 
'''A&E variables'''
#3.Numerators
# select A&E clinical events in month based on arrival date
ae_events = emergency_care_attendances.where(emergency_care_attendances.arrival_date.is_on_or_between(start_date, index_date))
# overall A&E attendances in month
dataset.ae_attendance_count = ae_events.count_for_patient()
# A&E PF-condition matching using GP codelists
# for name, codes in pf_conditions_gp_codes.items():
for name, codes in all_conditions_gp_codes.items(): 
    # primary diagnosis match
    ae_primary = ae_events.where(ae_events.diagnosis_01.is_in(codes))
    # non-primary diagnosis match
    ae_non_primary = ae_non_primary_diagnosis_matches(ae_events, codes)
    # count and flag
    setattr(dataset, f"ae_{name}_primary_count", ae_primary.count_for_patient())
    setattr(dataset, f"has_ae_{name}_non_primary", ae_non_primary)

# ---- A&E Medication : airadukunda --------------------------------------------
# OS TPP: https://docs.opensafely.org/ehrql/reference/schemas/tpp/
# In A&E, we use "diagnosis" fields (NOT SNOMED codes)
"""
for name, codes in all_conditions_gp_codes.items():
    # A&E attendances with the condition
    ae_primary = ae_events.where(ae_events.diagnosis_01.is_in(codes))
    attendance_ids = ae_primary.id
    # Step 2: All records from those attendances
    ae_medication_events = ae_events.where(ae_events.id.is_in(attendance_ids))
    
    # Any condition-specific medication
    count_medication, count_medication_episode = has_event_count(ae_medication_events,codelists.pharmacy_first_condition_specific_medications_dict[name], )
    setattr(dataset,  f"numerator_ae_medication_{name}",count_medication,)
    setattr(dataset,f"numerator_ae_medication_episode_{name}",count_medication_episode,)

    # First- and second-line medications
    for medication_name, medication_codes in codelists.pf_first_secondline_medications[name].items():
        count_medication, count_medication_episode = has_event_count(ae_medication_events,medication_codes,)
        setattr(dataset,f"numerator_ae_{medication_name}_{name}",count_medication,)
        setattr(dataset, f"numerator_ae_{medication_name}_episode_{name}",count_medication_episode,)
"""

########################################################
'''Appointments variables'''
# select attended appointments in month
dataset.appointment_scheduled = appointments.where(
    (appointments.start_date.is_on_or_between(start_date, index_date)) &
    (appointments.status.is_in([
            "Arrived",
            "In Progress",
            "Finished",
            "Visit",
            "Patient Walked Out",
            "Did Not Attend"
        ]))
).count_for_patient()
dataset.appointment_seen = appointments.where(
    (appointments.seen_date.is_on_or_between(start_date, index_date)) &
    (appointments.status.is_in([
            "Arrived",
            "In Progress",
            "Finished",
            "Visit",
            "Patient Walked Out",
            "Did Not Attend"
        ]))
).count_for_patient()

########################################################

show(dataset) # DEBUG: show the patients in the base population

########################################################
# Define measures for analysis
