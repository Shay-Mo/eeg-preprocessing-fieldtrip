# EEG Preprocessing Pipeline with MATLAB and FieldTrip

A modular MATLAB pipeline for preprocessing EEG recordings from the [Simon 
Conflict Task dataset](https://openneuro.org/datasets/ds003518/versions/1.0.0) using [FieldTrip](https://www.fieldtriptoolbox.org/).

The project implements a sequence of EEG preprocessing, artifact handling, 
Independent Component Analysis (ICA), trial classification, and 
Event-Related Potential (ERP) computation steps.

## Overview

This repository contains a MATLAB/FieldTrip pipeline for preprocessing EEG
data from a modified Simon Conflict Task (SCT), a reinforcement learning
paradigm combining spatial congruency (Simon effect) manipulations with
probabilistic feedback. The task design and dataset are from:

> Cavanagh, J. F., Masters, S. E., Bath, K., & Frank, M. J. (2014).
> Conflict acts as an implicit cost in reinforcement learning.
> *Nature Communications*, 5, 5394. https://doi.org/10.1038/ncomms6394

The pipeline is tailored to this dataset (110 subjects, 64-channel Brain
Vision system) and is not intended as a general-purpose EEG toolkit.
Preprocessing steps were designed for this project's own analysis goals, 
and are not part of the original study's pipeline.

The pipeline is organized into separate functions, with `sct_pipeline.m` 
serving as the main entry point. Processing is performed subject by 
subject, and intermediate results and processing logs are saved for 
subsequent analysis.

## Requirements

The pipeline uses MATLAB and the following external toolboxes:

- **[FieldTrip](https://www.fieldtriptoolbox.org/)** — The current pipeline
   configuration references FieldTrip version `fieldtrip-20250114`.
- **[Zapline-Plus](https://github.com/MariusKlug/Zapline-plus)** — Line-noise
  removal. The current configuration references version `zapline-plus-1.2.1`.
- An ICA artifact-detection toolbox adapted from [ADJUST](https://doi.org/10.1111/j.1469-8986.2010.01061.x)
  (Mognon et al., 2011), [auto-ica-checking](https://www.nitrc.org/docman/?group_id=739&selected_doc_group_id=4756) used in `sct_autoInspectICA`

## Processing Workflow

The current pipeline includes the following stages:

1. **Data loading** — Load EEG recordings and exclude the EOG channel from the EEG data.
2. **Line-noise removal** — Apply Zapline-Plus to reduce line noise.
3. **Band-pass filtering** — Apply high-pass filtering at 0.5 Hz and low-pass filtering at 60 Hz.
4. **Channel interpolation** — Reconstruct the CPz channel using the electrode layout, before and after ICA.
5. **Trial definition** — Segment the continuous recording into trials using the experiment's event information.
6. **Trial artifact rejection** — Identify and reject trials exceeding predefined amplitude or variability thresholds.
7. **Independent Component Analysis (ICA)** — Decompose the EEG signals into independent components.
8. **Component inspection and artifact removal** — Inspect ICA components and remove components identified as artifactual.
9. **Condition binning** — Assign trials to experimental conditions based on the task's event and feedback codes.
10. **ERP computation** — Apply baseline correction and calculate trial-averaged ERPs for the defined conditions.

The implementation is dataset-specific. Processing parameters and event-handling rules should be reviewed before applying the pipeline to other EEG experiments.

## Repository Structure

Functions are called from `sct_pipeline.m` in the following order:

| Step | Function | Purpose |
|---|---|---|
| 1 | `sct_loadRawData` | Loads raw EEG data, excluding the EOG channel |
| 2 | `sct_preprocess` | Removes line noise (Zapline-Plus), applies high/low-pass filters |
| 3 | `sct_interpolate` (pre-ICA) | Recreates the CPz reference channel via spatial interpolation |
| 4 | `sct_createLayout` | Builds the electrode layout from the electrode positions file |
| 5 | `sct_computeNeighbours` | Computes channel neighbour definitions for interpolation |
| 6 | `sct_defineTrials` | Segments continuous data into trials |
| 7 | `sct_trialfun` | Trial-definition function used by `sct_defineTrials` |
| 8 | `sct_autoInspectTrials` | Automatically flags and rejects bad trials |
| 9 | `sct_runICA` | Runs ICA decomposition on the cleaned trial data |
| 10 | `sct_autoInspectICA` | Automatically flags likely-artifactual components (ADJUST-based) |
| 11 | `sct_inspectICA` | Interactive GUI for manual review/confirmation of flagged components |
| 12 | `sct_rejectArtifacts` | Removes marked artifactual components from the data |
| 13 | `sct_interpolate` (post-ICA) | Recreates CPz again, now from ICA-cleaned neighbouring channels |
| 14 | `sct_defineBins` | Labels trials into congruency x feedback bins |
| 15 | `sct_computeERP` | Computes baseline-corrected, per-bin event-related potentials |
| 16 | `sct_plotTrials` | Opens an interactive databrowser for visual before/after-ICA inspection |

CPz is intentionally recreated twice (steps 3 and 13): once pre-ICA so a
complete channel montage is available for trial definition and
inspection (CPz itself is excluded from the ICA decomposition, since
interpolated data would violate ICA's full-rank requirement), and again
post-ICA so CPz is derived from neighbouring channels that have since
been cleaned of artifacts, rather than from their pre-ICA (potentially
contaminated) values.

## Data structure

The main script expects the project directories to follow this structure:

```text
project/
├── Raw_Data/
│   └── sub-001/
│       └── ses-01/
│           └── eeg/
│               ├── sub-001_ses-01_task-SimonConflict_eeg.set
│               ├── sub-001_ses-01_task-SimonConflict_eeg.fdt
│               └── sub-001_ses-01_task-SimonConflict_electrodes.tsv
├── FT_Results/
└── FT_Scripts/
    └── sct_pipeline.m
```

The example above illustrates the expected layout for one subject; 
additional subjects follow the same naming convention.

Results are written to `FT_Results/sub-XXX/`, created automatically if
it doesn't already exist.

## Setup

1. Clone this repository.
2. Install FieldTrip and Zapline-Plus, and note their install paths.
3. Open `sct_pipeline.m` and edit the `toolboxDIR` variable (and the
   `addpath` calls, if your folder names differ) to point to your local
   toolbox installations.
4. Ensure your raw data and scripts follows the expected directory layout 
   (see [Data structure](#data-structure) above).

## Usage

1. Open `sct_pipeline.m`.
2. Edit the `subjects` array to list the subject numbers you want to process.
3. Run the script. Each subject is processed independently inside a
   `try/catch` block, so an error on one subject won't halt the batch.
4. Output is written per-subject to `FT_Results/sub-XXX/`, including a
   `sub-XXX_log.txt` diary of console output for that run.

Note: `sct_inspectICA` opens an interactive GUI for manually marking
artifactual ICA components, so the pipeline is not fully unattended —
it pauses for manual review at that stage for each subject.

## Outputs

The pipeline saves intermediate and final data under `FT_Results`, organized
by subject, including:

- Preprocessed EEG data.
- Cleaned trial data and rejected-trial information.
- ICA-related data and inspection outputs.
- Baseline-corrected ERP structures.
- Subject-level processing logs.

The ERP output contains channel labels, a time vector, condition-bin information, 
and an array of averaged ERPs, facilitating subsequent research analyses.

## Scope and Limitations

- The current implementation is designed around the [Simon Conflict Task 
  dataset](https://openneuro.org/datasets/ds003518/versions/1.0.0) and its event structure.
- Filtering parameters, artifact thresholds, channel handling, and 
  condition definitions are experiment-specific.
- ICA artifact removal requires inspection and appropriate component 
  identification; automated preprocessing does not guarantee artifact-free data.
- The pipeline is not designed to generalize to other datasets or tasks 
  without modification.
- If you use `sct_autoInspectICA` or its underlying method, please cite
  the original ADJUST paper (Mognon et al., 2011) in any resulting work.

## Project Status

This repository documents an ongoing research-oriented MATLAB/FieldTrip 
workflow. The code and documentation may evolve as the analysis pipeline is refined.

