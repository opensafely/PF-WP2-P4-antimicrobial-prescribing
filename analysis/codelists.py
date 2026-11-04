from ehrql import codelist_from_csv

####################################################
#-------------P4--------------------------------------------------------------------------------------------------------------------------------------------------------------
# Here i added a codelist for medication and conditions for P4 : airadukunda
# Additional variables on medications (specific antimicrobial for the P4).For medicine we fir need to make sure if the fx  codelist_from_csv is colled at the begining as: 
#from ehrql import create_dataset, codelist_from_csv ( read the Using ehrQL to answer specific questions in OS documentation)
##1.PF conditions treatment (gp_dmd_codelist) : airadukunda 
aciclovir_codelist = codelist_from_csv("codelists/pharmacy-first-project-aciclovir.csv", column="code")
amoxicillin_codelist = codelist_from_csv("codelists/pharmacy-first-project-amoxicillin.csv", column="code")
cefalexin_codelist = codelist_from_csv("codelists/pharmacy-first-project-cefalexin.csv", column="code")
clarithromycin_codelist = codelist_from_csv("codelists/pharmacy-first-project-clarithromycin.csv", column="code")
clindamycin_codelist = codelist_from_csv("codelists/pharmacy-first-project-clindamycin.csv", column="code")
co_amoxiclav_codelist = codelist_from_csv("codelists/pharmacy-first-project-co-amoxiclav-oral-preparations.csv", column="code")
doxycycline_codelist = codelist_from_csv("codelists/pharmacy-first-project-doxycycline.csv", column="code")
erythromycin_codelist = codelist_from_csv("codelists/pharmacy-first-project-erythromycin.csv", column="code")
famciclovir_codelist = codelist_from_csv("codelists/pharmacy-first-project-famciclovir.csv", column="code")
flucloxacillin_codelist = codelist_from_csv("codelists/pharmacy-first-project-flucloxacillin.csv", column="code")
fosfomycin_codelist = codelist_from_csv("codelists/pharmacy-first-project-fosfomycin.csv", column="code")
fusidic_acid_cream_codelist = codelist_from_csv("codelists/pharmacy-first-project-fusidic-acid-cream.csv", column="code")
metronidazole_codelist = codelist_from_csv("codelists/pharmacy-first-project-metronidazole.csv", column="code")
mupirocin_codelist = codelist_from_csv("codelists/pharmacy-first-project-mupirocin.csv", column="code")
nitrofurantoin_codelist = codelist_from_csv("codelists/pharmacy-first-project-nitrofurantoin.csv", column="code")
phenoxymethylpenicillin_codelist = codelist_from_csv("codelists/pharmacy-first-project-phenoxymethylpenicillin.csv", column="code")
pivmecillinam_codelist = codelist_from_csv("codelists/pharmacy-first-project-pivmecillinam.csv", column="code")
trimethoprim_codelist = codelist_from_csv("codelists/pharmacy-first-project-trimethoprim.csv", column="code")
valaciclovir_codelist = codelist_from_csv("codelists/pharmacy-first-project-valaciclovir.csv", column="code")

#2.PF control conditions (gp_snomed_codelist) : airadukunda
acute_bronchitis_control_codelist = codelist_from_csv("codelists/pharmacy-first-project-acute-bronchitis-as-acute-sore-throat-control.csv",column="code")
conjunctivitis_allergic_control_codelist = codelist_from_csv("codelists/pharmacy-first-project-conjunctivitis-allergic-as-infected-insect-bites-control.csv",column="code")
vulvovaginal_candidiasis_control_codelist = codelist_from_csv("codelists/pharmacy-first-project-vulvovaginal-candidiasis-as-uti-control.csv",column="code")

#3.PF conditions (gp_snomed_codelist) :airadukunda
impetigo_codelist = codelist_from_csv("codelists/pharmacy-first-project-impetigo-codes-for-pharmacy-first-clone.csv",column="code")
#infected_insect_bites_codelist = codelist_from_csv("codelists/pharmacy-first-project-Infected-insect-bites-codes-for-pharmacy-first-clone.csv",column="code")
infected_insect_bites_codelist = codelist_from_csv("codelists/pharmacy-first-project-infected-insect-bites-codes-for-pharmacy-first-strict-definition.csv",column="code")
otitis_media_codelist = codelist_from_csv("codelists/pharmacy-first-project-otitis-media-codes-for-pharmacy-first-clone.csv",column="code")
shingles_codelist = codelist_from_csv("codelists/pharmacy-first-project-shingles-for-pharmacy-first-clone.csv",column="code")
sinusitis_codelist = codelist_from_csv("codelists/pharmacy-first-project-sinusitis-codes-for-pharmacy-first-clone.csv",column="code")
sore_throat_codelist = codelist_from_csv("codelists/pharmacy-first-project-sore-throat-codes-for-pharmacy-first-clone.csv",column="code")
uti_codelist = codelist_from_csv("codelists/pharmacy-first-project-urinary-tract-infection-codes-for-pharmacy-first-clone.csv",column="code")

#---------------controls conditions------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
#1.Acute bronchitis medications (existing medications)
"""
doxycycline_codelist
amoxicillin_codelist
clarithromycin_codelist
erythromycin_codelist
"""
# 2. Allergic conjunctivitis medications(new medications)
antazoline_codelist = codelist_from_csv("codelists/pharmacy-first-project-antazoline.csv", column="code")
azelastine_codelist = codelist_from_csv("codelists/pharmacy-first-project-azelastine.csv", column="code")
epinastine_codelist = codelist_from_csv("codelists/pharmacy-first-project-epinastine.csv", column="code")
ketotifen_codelist = codelist_from_csv("codelists/pharmacy-first-project-ketotifen.csv", column="code")
lodoxamide_codelist = codelist_from_csv("codelists/pharmacy-first-project-lodoxamide.csv", column="code")
olopatadine_codelist = codelist_from_csv("codelists/pharmacy-first-project-olopatadine.csv", column="code")
sodium_cromoglicate_codelist = codelist_from_csv("codelists/pharmacy-first-project-sodium-cromoglicate.csv", column="code")

#3.Vaginal candidiasis medications
clotrimazole_codelist = codelist_from_csv("codelists/pharmacy-first-project-clotrimazole.csv", column="code")
econazole_codelist = codelist_from_csv("codelists/pharmacy-first-project-econazole-nitrate.csv", column="code")
fenticonazole_codelist = codelist_from_csv("codelists/pharmacy-first-project-fenticonazole.csv", column="code")
fluconazole_codelist = codelist_from_csv("codelists/pharmacy-first-project-fluconazole.csv", column="code")
miconazole_codelist = codelist_from_csv("codelists/pharmacy-first-project-miconazole-nitrate.csv", column="code")
#itraconazole_codelist = codelist_from_csv("codelists/pharmacy-first-project-itraconazole.csv", column="code")

# 4.Dictionaries
# 4.1.all pharmacy_first_conditions_dict
pharmacy_first_conditions_dict = {   #airadukunda
    "uti": uti_codelist,
    "sinusitis": sinusitis_codelist,
    "insectbite": infected_insect_bites_codelist,  #here the name are similar to PF sample name insectbite instead insect_bite for example
    "otitismedia": otitis_media_codelist,
    "sorethroat": sore_throat_codelist,
    "shingles": shingles_codelist,
    "impetigo": impetigo_codelist,
    "all_pharmacy_first_conditions": (
        uti_codelist
        + sinusitis_codelist
        + infected_insect_bites_codelist
        + otitis_media_codelist
        + sore_throat_codelist
        + shingles_codelist
        + impetigo_codelist
    ),
}
# 4.2.all pharmacy_first_controls_conditions dict

pharmacy_first_controls_conditions_dict = {  #airadukunda
    "acute_bronchitis": acute_bronchitis_control_codelist,
    "conjunctivitis_allergic": conjunctivitis_allergic_control_codelist,
    "vulvovaginal_candidiasis": vulvovaginal_candidiasis_control_codelist,
    "all_pharmacy_first_controls_conditions": (                                  # no need to combine them
         acute_bronchitis_control_codelist
        + conjunctivitis_allergic_control_codelist
        + vulvovaginal_candidiasis_control_codelist
    ),
}
#4.3.All pharmacy first medications dictionary # use "for medication, codelist in pharmacy_first_medications_dict.items():..." for loop over all 
pharmacy_first_medications_dict = {
    "aciclovir": aciclovir_codelist,
    "amoxicillin": amoxicillin_codelist,
    "cefalexin": cefalexin_codelist,
    "clarithromycin": clarithromycin_codelist,
    "clindamycin": clindamycin_codelist,
    "co_amoxiclav": co_amoxiclav_codelist,
    "doxycycline": doxycycline_codelist,
    "erythromycin": erythromycin_codelist,
    "famciclovir": famciclovir_codelist,
    "flucloxacillin": flucloxacillin_codelist,
    "fosfomycin": fosfomycin_codelist,
    "fusidic_acid_cream": fusidic_acid_cream_codelist,
    "metronidazole": metronidazole_codelist,
    "mupirocin": mupirocin_codelist,
    "nitrofurantoin": nitrofurantoin_codelist,
    "phenoxymethylpenicillin": phenoxymethylpenicillin_codelist,
    "pivmecillinam": pivmecillinam_codelist,
    "trimethoprim": trimethoprim_codelist,
    "valaciclovir": valaciclovir_codelist,
    "all_pharmacy_first_medications": (
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
    ),
}
#4.4.pharmacy_first_condition_specific_medications
pharmacy_first_condition_specific_medications_dict = {
    "uti": (
        nitrofurantoin_codelist
        + trimethoprim_codelist
        + fosfomycin_codelist
        + pivmecillinam_codelist
        + co_amoxiclav_codelist
        + cefalexin_codelist
        + amoxicillin_codelist
    ),
    "impetigo": (
        fusidic_acid_cream_codelist
        + flucloxacillin_codelist
        + clarithromycin_codelist
        + erythromycin_codelist
        + mupirocin_codelist
    ),
    "insectbite": (
        flucloxacillin_codelist
        + clarithromycin_codelist
        + erythromycin_codelist
        + co_amoxiclav_codelist
        + metronidazole_codelist
        + clindamycin_codelist
        + doxycycline_codelist
    ),
    "otitismedia": (
        amoxicillin_codelist
        + clarithromycin_codelist
        + erythromycin_codelist
        + co_amoxiclav_codelist
    ),
    "shingles": (
        aciclovir_codelist
        + valaciclovir_codelist
        + famciclovir_codelist
    ),
    "sinusitis": (
        phenoxymethylpenicillin_codelist
        + clarithromycin_codelist
        + erythromycin_codelist
        + doxycycline_codelist
        + co_amoxiclav_codelist
    ),
    "sorethroat": (
        phenoxymethylpenicillin_codelist
        + clarithromycin_codelist
        + erythromycin_codelist
    ),
    "all_conditions": (  # Combined Pharmacy First medications
        nitrofurantoin_codelist +
        trimethoprim_codelist +
        fosfomycin_codelist +
        pivmecillinam_codelist +
        cefalexin_codelist +
        amoxicillin_codelist +
        fusidic_acid_cream_codelist +
        flucloxacillin_codelist +
        clarithromycin_codelist +
        erythromycin_codelist +
        mupirocin_codelist +
        metronidazole_codelist+
        clindamycin_codelist +
        doxycycline_codelist +
        phenoxymethylpenicillin_codelist +
        aciclovir_codelist +
        valaciclovir_codelist +
        famciclovir_codelist +
        co_amoxiclav_codelist
    ),
    "acutebronchitis_control": (# controls condition specific medications 
        doxycycline_codelist
        + amoxicillin_codelist
        + clarithromycin_codelist
        + erythromycin_codelist
    ),
    "conjunctivitisallergic_control": (
        sodium_cromoglicate_codelist # new
        + lodoxamide_codelist     # new
        + antazoline_codelist     # new
        + epinastine_codelist     # new
        + ketotifen_codelist      # new
        + olopatadine_codelist    # new
    ),
    "vulvovaginalcandidiasis_control": (
        fluconazole_codelist      # new
        + clotrimazole_codelist   # new
        + miconazole_codelist     # new
        + miconazole_codelist     # new
        + fenticonazole_codelist  # new
        #+ itraconazole_codelist  # new
    ),
}

#4.5.PF firt and secondline medication (to be validated)

pf_first_secondline_medications = {
    "uti": {
        "nitrofurantoin": nitrofurantoin_codelist,
        "trimethoprim": trimethoprim_codelist,
    },
    "sinusitis": {
        "phenoxymethylpenicillin": phenoxymethylpenicillin_codelist,
        "doxycycline": doxycycline_codelist,
    },
    "insectbite": {
        "flucloxacillin": flucloxacillin_codelist,
        "clarithromycin": clarithromycin_codelist,
    },
    "otitismedia": {
        "amoxicillin": amoxicillin_codelist,
        "clarithromycin": clarithromycin_codelist,
    },
    "sorethroat": {
        "phenoxymethylpenicillin": phenoxymethylpenicillin_codelist,
        "clarithromycin": clarithromycin_codelist,
    },
    "shingles": {
        "aciclovir": aciclovir_codelist,
        "valaciclovir": valaciclovir_codelist,
    },
    "impetigo": {
        "fusidic_acid": fusidic_acid_cream_codelist,
        "flucloxacillin": flucloxacillin_codelist,
    },
    "all_conditions": {                          # We assummed  the two antibiotics to be commonly prescribed in primary care
        "amoxicillin": amoxicillin_codelist,
        "doxycycline": doxycycline_codelist,
    },
    "acutebronchitis_control": {
        "amoxicillin": amoxicillin_codelist,
        "doxycycline":doxycycline_codelist,  
    },
    "conjunctivitisallergic_control": {
        "Sodium_cromoglicate": sodium_cromoglicate_codelist,
        "Olopatadine": olopatadine_codelist,
    },
    "vulvovaginalcandidiasis_control": {
        "Clotrimazole": clotrimazole_codelist,
        "Fluconazole": fluconazole_codelist,
    },

}
#4.6.Medication for controls 

control_condition_specific_medications_dict = {
    "acutebronchitis": (
        doxycycline_codelist
        + amoxicillin_codelist
        + clarithromycin_codelist
        + erythromycin_codelist
    ),

    "conjunctivitisallergic": (
        sodium_cromoglicate_codelist # new
        + lodoxamide_codelist     # new
        + antazoline_codelist     # new
        + epinastine_codelist     # new
        + ketotifen_codelist      # new
        + olopatadine_codelist    # new
    ),
    "vulvovaginalcandidiasis": (
        fluconazole_codelist      # new
        + clotrimazole_codelist   # new
        + miconazole_codelist     # new
        + fenticonazole_codelist  # new
        #+ itraconazole_codelist  # new
    ),
}

#---------------------------------------------P2--------------------------------------------------------------------------------------------------------------------------------------------------------------------- 
# SNOMED UK ethnicity category codelist - latest version 22911876
ethnicity_group6_codelist = codelist_from_csv(
    "codelists/opensafely-ethnicity-snomed-0removed.csv",
    column="code",
    category_column="Grouping_6",
)
ethnicity_group16_codelist = codelist_from_csv(
    "codelists/opensafely-ethnicity-snomed-0removed.csv",
    column="code",
    category_column="Grouping_16",
)

# consultation type -- pending update
gp_codelist_consultation_f2f = codelist_from_csv(
    "codelists/pharmacy-first-project-face-to-face-consultation-codes-for-pharmacy-first.csv",
    column="code"
)
gp_codelist_consultation_online = codelist_from_csv(
    "codelists/pharmacy-first-project-online-consultation-codes-for-pharmacy-first.csv",
    column="code"
)
gp_codelist_consultation_telephone = codelist_from_csv(
    "codelists/pharmacy-first-project-telephone-consultation-codes-for-pharmacy-first.csv",
    column="code"
)

#PF conditions snomed codes used within PF
tx_codelist_pf_otitis_media = codelist_from_csv(
    "codelists/opensafely-pharmacy-first-acute-otitis-media-treatment-full-dmd-codelist.csv",
    column="code",
)
 
tx_codelist_pf_impetigo = codelist_from_csv(
    "codelists/opensafely-pharmacy-first-impetigo-treatment-full-dmd-codelist.csv",
    column="code",
)
 
tx_codelist_pf_infected_insect_bites = codelist_from_csv(
    "codelists/opensafely-pharmacy-first-infected-insect-bites-treatment-full-dmd-codelist.csv",
    column="code",
)
 
tx_codelist_pf_shingles = codelist_from_csv(
    "codelists/opensafely-pharmacy-first-shingles-treatment-full-dmd-codelist.csv",
    column="code",
)
 
tx_codelist_pf_sinusitis = codelist_from_csv(
    "codelists/opensafely-pharmacy-first-sinusitis-treatment-full-dmd-codelist.csv",
    column="code",
)
 
tx_codelist_pf_sore_throat = codelist_from_csv(
    "codelists/opensafely-pharmacy-first-sore-throat-treatment-full-dmd-codelist.csv",
    column="code",
)
 
tx_codelist_pf_urinary_tract_infection = codelist_from_csv(
    "codelists/opensafely-pharmacy-first-urinary-tract-infection-treatment-full-dmd-codelist.csv",
    column="code",
)

####################################################
#Snomed codes used for PF conditions by GPs
gp_snomed_codelist_uti = codelist_from_csv(
    "codelists/pharmacy-first-project-urinary-tract-infection-and-related-conditions.csv",
    column="code",
)  
gp_snomed_codelist_impetigo = codelist_from_csv(
    "codelists/pharmacy-first-project-impetigo-related-conditions-administration-codes-for-pharmacy-first.csv",
    column="code",
) 
gp_snomed_codelist_otitis_media = codelist_from_csv(
    "codelists/pharmacy-first-project-otitis-media-and-related-conditions.csv",
    column="code",
) 
gp_snomed_codelist_sinusitis = codelist_from_csv(
    "codelists/pharmacy-first-project-sinusitis-related-conditions-administration-codes-for-pharmacy-first.csv",
    column="code",
) 
gp_snomed_codelist_sore_throat = codelist_from_csv(
    "codelists/pharmacy-first-project-Sore-throat-and-related-conditions.csv",
    column="code",
) 
gp_snomed_codelist_insect_bites = codelist_from_csv(
    "codelists/pharmacy-first-project-insect-bites-and-related-conditions-administration-codes-for-pharmacy-first.csv",
    column="code",
) 
gp_snomed_codelist_shingles = codelist_from_csv(
    "codelists/pharmacy-first-project-shingles-and-related-conditions-for-pharmacy-first.csv",
    column="code",
)

####################################################
#Snomed codes used for control conditions by GPs
gp_snomed_codelist_lower_back_pain = codelist_from_csv(
    "codelists/pharmacy-first-project-lower-back-pain-for-pf-control.csv",
    column="code",
)


####################################################
#Snomed codes used for specific conditions by GPs - population exclusion criteria
gp_snomed_codelist_urinary_catheter = codelist_from_csv(
    "codelists/pharmacy-first-project-urinary-catheter-administration-codes-for-pharmacy-first.csv",
    column="code",
)

#Snomed codes used for specific conditions by GPs - population exclusion criteria
gp_snomed_codelist_bullous_impetigo = codelist_from_csv(
    "codelists/pharmacy-first-project-bullous-impetigo-administration-codes-for-pharmacy-first.csv",
    column="code",
)

#Snomed codes used for specific conditions by GPs - population exclusion criteria
#current version: pregnancy code by NHSD
gp_snomed_codelist_pregnancy = codelist_from_csv(
    "codelists/nhsd-primary-care-domain-refsets-preg_cod.csv",
    column="code",
    category_column="term",
)

# Import no-longer-pregnant codelist
gp_snomed_codelist_end_pregnancy = codelist_from_csv(
    "codelists/pharmacy-first-project-end-of-pregnancy-narrow.csv",
    column="code",
    category_column="term",
)

# estimated date of delivery
gp_snomed_codelist_pregnancy_edd = codelist_from_csv (
    "codelists/user-VickiPalin-pregnancy_edd_snomed.csv"
    , column = "code"
)
####################################################
"""
pf_med_codelist = (
    acute_otitis_media_tx_codelist
    + impetigo_treatment_tx_codelist
    + infected_insect_bites_tx_codelist
    + shingles_treatment_tx_codelist
    + sinusitis_tx_codelist
    + sore_throat_tx_codelist
    + urinary_tract_infection_tx_codelist
)
"""

# Community Pharmacist Consultation Service for minor illness - 1577041000000109
pf_consultation_cp_minorillness = ["1577041000000109"]
# Pharmacy First service - 983341000000102
pf_consultation_service = ["983341000000102"]
# Community Pharmacy First Service - 2129921000000100 - not used (?)
pf_consultation_cp_service = ["2129921000000100"]
 
pf_consultation_events_dict = {
    "pf_consultation_cp_minorillness": pf_consultation_cp_minorillness, # Community Pharmacist (CP) Consultation Service for minor illness (procedure)
    "pf_consultation_service": pf_consultation_service, # Pharmacy First service (qualifier value)
    "pf_consultation_cp_service": pf_consultation_cp_service, # Community Pharmacy Pharmacy First Service
    "pf_consultation_services_combined": pf_consultation_cp_minorillness + pf_consultation_service + pf_consultation_cp_service,
    # "pf_consultation_services_combined": pf_consultation_service + pf_consultation_cp_service,
}
 #NHS Community Pharmacist Consultation Service???
 
uti_code = ["1090711000000102"] # one code in CPs,multiple codes in GPs
sinusitis_code = ["15805002"]
insectbite_code = ["262550002"]
otitismedia_code = ["3110003"]
sorethroat_code = ["363746003"]
shingles_code = ["4740000"]
impetigo_code = ["48277006"]
