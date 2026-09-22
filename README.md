# PFE-WP2-Protocol4-antimicrobial-prescribing

[View on OpenSAFELY](https://jobs.opensafely.org/repo/https%253A%252F%252Fgithub.com%252Fopensafely%252FWP2-PharmacyFirst-Protocol4-antimicrobial-prescribing)

Details of the purpose and any published outputs from this project can be found at the link above.

The contents of this repository MUST NOT be considered an accurate or valid representation of the study or its purpose. 
This repository may reflect an incomplete or incorrect analysis with no further ongoing work.
The content has ONLY been made public to support the OpenSAFELY [open science and transparency principles](https://www.opensafely.org/about/#contributing-to-best-practice-around-open-science) and to support the sharing of re-usable code for other subsequent users.
No clinical, policy or safety conclusions must be drawn from the contents of this repository.

# Project oververview 
>Last updates : September 22, 2026.

>This repository contains the analytical code and study materials for Protocol 4 (P4) of Work Package 2 (WP2) within the Pharmacy First Evaluation programme.

The objective of this study is to evaluate changes in antimicrobial prescribing following the introduction of the NHS Pharmacy First service in England. Specifically, the study aims to:

                             1.Quantify changes in antimicrobial prescribing volume following Pharmacy First implementation.
                             2.Assess condition-specific prescribing patterns across the seven Pharmacy First conditions.
                             3.Evaluate changes in first-line antibiotic prescribing by antimicrobial class.
                             4.Examine changes in the proportion of consultations resulting in antimicrobial prescribing.
                             5.Assess changes in antibiotic prescription duration.

The study uses routinely collected NHS primary care electronic health records available through the OpenSAFELY-TPP platform and applies interrupted time series methods to evaluate prescribing trends before and after Pharmacy First implementation.

**Study Design**

          Quasi-experimental interrupted time series design.
          Observation period: February 2022 to February 2026.
          Unit of analysis: General practice (GP) monthly prescribing data.
          Data source: OpenSAFELY-TPP linked NHS datasets.

The repository will be organised around several core components:

         1.patient-level dataset generation
         2.practice-level aggregation and summary 
         3.validation workflows, including  pregnancy variable checking and validation several patient-level measures snomed code occurrancence counting
# Pharmacy Firt conditions and medication linkage 

For each patient, clinical events and medication records occurring within the study period are linked using a shared consultation identifier (*consultation_id*) available in [tpp schema](https://docs.opensafely.org/ehrql/reference/schemas/tpp/),defining  the data (both primary care and externally linked) available in the OpenSAFELY-TPP backend.This approach ensures that antimicrobial prescriptions are attributed only to the consultation in which the relevant PF condition was recorded, rather than to unrelated consultations occurring on nearby or on the same  dates. For example, a patient is classified as having received nitrofurantoin for a urinary tract infection (UTI) only if both the UTI clinical event and the nitrofurantoin prescription share the same consultation identifier. 
We believe that this method provides a specificity of treatment attribution and reduces misclassification compared with date-based matching alone.
 **Digagram 1**  illustrates the consultation ID -based linkage approach used to identify treatments associated with Pharmacy First conditions. 

**Diagram 1**. *Consultation ID-based linkage between clinical events and treatments*
```mermaid
graph TD

%% Input data
A[Clinical Events]
B[Medication Records]

%% UTI identification
A --> C[Filter UTI SNOMED Codes]
C --> D[UTI Events]

%% Treatment identification
B --> E[Filter Nitrofurantoin dmd Codes]
E --> F[Nitrofurantoin Prescriptions]

%% Consultation matching
D --> G[UTI Consultation IDs]
F --> H[Medication Consultation IDs]

G --> I{Consultation IDs Match?}
H --> I

%% Outcome
I --> J[UTI Consultation<br/>with Nitrofurantoin]

%% Comparison
J --> K[Pre-Pharmacy First<br/>2022-2024]
J --> L[Post-Pharmacy First<br/>2024-2026]

K --> M[Compare Prescribing Rates]
L --> M

%% Classes
classDef clinical fill:#E8F5E9,stroke:#2E7D32,stroke-width:2px,color:#000;
classDef medication fill:#E3F2FD,stroke:#1565C0,stroke-width:2px,color:#000;
classDef consult fill:#FFF8E1,stroke:#F9A825,stroke-width:2px,color:#000;
classDef outcome fill:#FCE4EC,stroke:#C2185B,stroke-width:2px,color:#000;
classDef compare fill:#EDE7F6,stroke:#5E35B1,stroke-width:2px,color:#000;

class A,C,D clinical;
class B,E,F medication;
class G,H,I consult;
class J outcome;
class K,L,M compare;
```
# Patient-level measure generation workflow

The **Diagram 2** presents the workflow used to generate patient-level PF  measures from routinely collected electronic health records. Clinical events are first filtered using condition-specific SNOMED CT codelists to identify eligible Pharmacy First consultations, such as urinary tract infections, impetigo, sinusitis, shingles, infected insect bites, and sore throat. Medication records are then filtered using corresponding dm+d codelists and linked to clinical events through consultation identifiers(**consultations_id**). The resulting linked records are used to derive patient-level indicators describing whether a condition occurred, whether treatment was supplied during the same consultation, and the type and number of treatments prescribed.

For each month, a patient-level dataset is produced containing information on PF  conditions, associated treatments, and relevant demographic characteristics.These monthly datasets are subsequently combined into a single longitudinal analytical dataset that supports the evaluation of trends in condition presentations and prescribing patterns over time.
We will run montly data [multiple times](https://docs.opensafely.org/ehrql/how-to/multiple-time-periods/) through Pass parameters [project.yaml] or through [measures framework](https://docs.opensafely.org/ehrql/explanation/measures/)

**Diagram 2**. *Patient-level measure generation workflow*

```mermaid
graph TD

A[Clinical Events]

A --> B1[UTI]
A --> B2[Impetigo]
A --> B3[Sinusitis]
A --> B4[Shingles]
A --> B5[Insect Bite]
A --> B6[Sore Throat]
A --> B7[Otitis Media]


B1 --> C1[Match by Consultation ID]
B2 --> C2[Match by Consultation ID]
B3 --> C3[Match by Consultation ID]
B4 --> C4[Match by Consultation ID]
B5 --> C5[Match by Consultation ID]
B6 --> C6[Match by Consultation ID]
B7 --> C7[Match by Consultation ID]

C1 --> D[Patient-Level Measures]
C2 --> D
C3 --> D
C4 --> D
C5 --> D
C6 --> D
C7 --> D

D --> E[Monthly Datasets]
E --> F[Combined Dataset]

F --> G[Pre-Pharmacy First<br/>2022-2024]
F --> H[Post-Pharmacy First<br/>2024-2026]

G --> I[Compare Outcomes]
H --> I

%% Styling
classDef source fill:#ECEFF1,stroke:#37474F,stroke-width:2px;
classDef condition fill:#E8F5E9,stroke:#2E7D32,stroke-width:2px;
classDef matching fill:#FFF3E0,stroke:#EF6C00,stroke-width:2px;
classDef measure fill:#E3F2FD,stroke:#1565C0,stroke-width:2px;
classDef output fill:#F3E5F5,stroke:#6A1B9A,stroke-width:2px;

class A source;
class B1,B2,B3,B4,B5,B6,B7 condition;
class C1,C2,C3,C4,C5,C6,C7 matching;
class D,E,F measure;
class G,H,I output;
```


>## Core patient-level dataset definitions

- [dataset_definition_patients_Arnaud](analysis/dataset_definition_patients_Arnaud.py): Main patient-level dataset definition used to generate monthly datasets for downstream analyses. Monthly datasets are generated separately for each study month.
- [dataset_definition_patients_measures_Arnaud](analysis/dataset_definition_patients_measures_Arnaud.py): Separate patient-level dataset definition used specifically for generating measures and validation outputs. This dataset is primarily used for measure generation, exploratory summaries and validation, and practice-level aggregation.


>## Codelists
In codelists file (**codelists/**), we have a combination of codelists for P2 and P4. The codelists for P4 include specific antimicrobial treatment (Amoxicillin), PF conditions which are indexed as **"name of conditions " codes for pharmacy first**, and controls for which are named **"name of the condition " as control for " name of the PF condition"**. All these codelists were added using  : **opensafely codelists add link from OpenCodelists** in the VSC's terminal.

## Data dictionnary
All variables created for this analysis are described in the [Data dictionary](https://lshtm.sharepoint.com/:x:/r/sites/PharmacyFirstEvaluation_Group/Shared%20Documents/WP2%20-%20Development%20of%20data%20linkages/Protocols/WP2%20P4%20SAP/WP2%20P4%20Data%20dictonary/Data_dictionary_for_Protocol_4_June_26.xlsx?d=wd16305ce30384b22a5920c02d82ec82b&csf=1&web=1&e=zuoGZ0) The Excel workbook contains separate sheets describing patient-level data, practice-level data, and measures used for Protocol 4. The Data Dictionary is a living document and may be updated during the data analysis process to reflect changes to variable definitions, derived measures, or other analytical requirements.

## About the OpenSAFELY framework

The OpenSAFELY framework is a Trusted Research Environment (TRE) for electronic
health records research in the NHS, with a focus on public accountability and
research quality.

Read more at [OpenSAFELY.org](https://opensafely.org).

## Licences
As standard, research projects have a MIT license. 
