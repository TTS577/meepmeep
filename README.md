# meepmeep

```text


             .-""-.    
            /  _   \       
           | ( )( ) |-._____     
           | / //  |         `-. 
            ////          |      \
          ////`-._.-'   |     |   |
         //      \\  |     |      /
                      `-.____.-'
                         _| |_  
  
```

A Snakemake pipeline for human data depletion and bacterial whole-genome
sequencing (WGS) based on Oxford Nanopore Technology (ONT) long reads.
This pipeline is compatible for bacterial enrichment methods, where human
DNA is also sequenced but needs to be depleted prior to bacterial genome 
assembly. 

## Pipeline overview

| Step | Rule | Tool | Description |
|------|------|------|-------------|
| 01 | `nanostat_raw` | NanoStat | QC of raw reads |
| 02 | `human_depletion_minimap2` | minimap2 + samtools | Deplete human reads |
| 03 | `porechop` | Porechop | Adapter trimming |
| 04 | `nanostat_clean` | NanoStat | QC of cleaned reads |
| 05 | `filtlong` | Filtlong | Quality filtering |
| 06 | `flye` | Flye | De novo assembly |
| 07 | `quast` | QUAST | QC of unpolished assembly |
| 08 | `medaka` | Medaka | Long-read polishing |
| 09 | `checkm2` | CheckM2 | Genome completeness & contamination |
| 10 | `quast_polished` | QUAST | QC of polished assembly |
| 11 | `multiqc` | MultiQC | Aggregate all QC reports |

## Requirements

- [Snakemake](https://snakemake.readthedocs.io/) ≥ 7.0
- [Conda](https://docs.conda.io/) or [Mamba](https://mamba.readthedocs.io/) (recommended for faster env creation)

## Conda environments

Each tool runs in its own isolated conda environment to avoid Python version
conflicts. Snakemake creates and caches these automatically on first run.

| Environment file | Tool(s) | Python constraint |
|-----------------|---------|-------------------|
| `envs/env_nanostat.yaml` | NanoStat | ≥ 3.9 |
| `envs/env_minimap2_samtools.yaml` | minimap2 + samtools | ≥ 3.9 |
| `envs/env_porechop.yaml` | Porechop | ≥ 3.9, < 3.10 (unmaintained tool) |
| `envs/env_filtlong.yaml` | Filtlong | ≥ 3.9 |
| `envs/env_flye.yaml` | Flye | ≥ 3.9 |
| `envs/env_quast.yaml` | QUAST | ≥ 3.9, < 3.11 |
| `envs/meep_medaka.yaml` | Medaka | ≥ 3.9, < 3.11 |
| `envs/meep_checkm2.yaml` | CheckM2 | ≥ 3.9 |
| `envs/env_multiqc.yaml` | MultiQC | ≥ 3.9 |

## Setup

Retrieve the repo, make sure it is all lowercase:
```bash
git clone https://github.com/tts577/meepmeep.git 
```
