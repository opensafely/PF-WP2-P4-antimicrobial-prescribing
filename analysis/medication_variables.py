"""
Medication variables for the Pharmacy First  validation.

I placed this file in analysis/ and will call it from
analysis/dataset_definition_patients_measures_Arnaud.py, AFTER `dataset` is created:

    from analysis.medication_variables import add_medication_variables
    add_medication_variables(dataset)

It adds, for each PF condition:
  - numerator_medication_<condition> : number of medication events in the interval
                                       matching the condition codelist
  - has_medication_<condition>       : 1 if at least one such event in the interval
and
  - has_medication_any               : 1 if any of the 7 conditions has a medication

No A&E variables are used here.
"""

from ehrql import INTERVAL, codelist_from_csv
from ehrql.tables.tpp import medications

PF_CONDITIONS = [
    "uti",
    "sinusitis",
    "insectbite",
    "otitismedia",
    "sorethroat",
    "shingles",
    "impetigo",
]

# ---------------------------------------------------------------------------
# PLACEHOLDER codelists: one dm+d codelist per condition.
# Replace the file names with your real codelists (and list them in codelists.txt).
# Each CSV must have a column named "code" containing dm+d codes.
# ---------------------------------------------------------------------------
MEDICATION_CODELIST_PATHS = {
    "uti": "codelists/local-pf-medication-uti.csv",
    "sinusitis": "codelists/local-pf-medication-sinusitis.csv",
    "insectbite": "codelists/local-pf-medication-insectbite.csv",
    "otitismedia": "codelists/local-pf-medication-otitismedia.csv",
    "sorethroat": "codelists/local-pf-medication-sorethroat.csv",
    "shingles": "codelists/local-pf-medication-shingles.csv",
    "impetigo": "codelists/local-pf-medication-impetigo.csv",
}

MEDICATION_CODELISTS = {
    condition: codelist_from_csv(path, column="code")
    for condition, path in MEDICATION_CODELIST_PATHS.items()
}


def add_medication_variables(dataset):
    """Attach medication variables to an existing ehrQL dataset."""

    # Medication events falling inside the measure interval
    meds_in_interval = medications.where(
        medications.date.is_on_or_between(INTERVAL.start_date, INTERVAL.end_date)
    )

    has_any = None

    for condition in PF_CONDITIONS:
        condition_meds = meds_in_interval.where(
            medications.dmd_code.is_in(MEDICATION_CODELISTS[condition])
        )

        # number of medication events (like the consultation counts)
        setattr(
            dataset,
            f"numerator_medication_{condition}",
            condition_meds.count_for_patient(),
        )

        # patient-level flag: at least one medication event
        has_flag = condition_meds.exists_for_patient()
        setattr(dataset, f"has_medication_{condition}", has_flag)

        has_any = has_flag if has_any is None else (has_any | has_flag)

    dataset.has_medication_any = has_any
