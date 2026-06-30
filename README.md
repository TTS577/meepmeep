# meepmeep

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

### 1. Sample sheet

Edit `config/samples.tsv` to list your samples and their FASTQ paths:

```
Pipeline for human data depletion and bacterial whole-genome sequencing (WGS) based on Oxford Nanopore Technology (ONT) long-read sequencing.

## Pipeline overview

| Step | Rule | Tool | Container |
|------|------|------|-----------|
| 1 | `nanostat_raw` | NanoStat | `longread-env` |
| 2 | `human_depletion_minimap2` | minimap2 + samtools | `longread-env` |
| 3 | `porechop` | Porechop | `longread-env` |
| 4 | `nanostat_clean` | NanoStat | `longread-env` |
| 5 | `filtlong` | Filtlong | `longread-env` |
| 6 | `flye` | Flye | `longread-env` |
| 7 | `quast` | QUAST | `assembly-tools` |
| 8 | `medaka` | Medaka | `medaka` |
| 9 | `checkm2` | CheckM2 | `checkm2` |
| 10 | `multiqc` | MultiQC | `assembly-tools` |

## Container images

All pipeline steps run inside Docker/Apptainer (Singularity) containers hosted on the GitHub Container Registry:

| Image | Tools |
|-------|-------|
| `ghcr.io/tts577/meepmeep/longread-env:latest` | minimap2, samtools, porechop, filtlong, flye, nanostat |
| `ghcr.io/tts577/meepmeep/assembly-tools:latest` | QUAST, MultiQC |
| `ghcr.io/tts577/meepmeep/medaka:latest` | Medaka 1.11.3 |
| `ghcr.io/tts577/meepmeep/checkm2:latest` | CheckM2 |

Images are built automatically via GitHub Actions (`.github/workflows/build-containers.yml`) whenever the `envs/` or `containers/` directories change.

## Requirements

- [Snakemake](https://snakemake.readthedocs.io) ≥ 8
- [Apptainer / Singularity](https://apptainer.org) (for container execution)

## Setup

### 1. Edit the sample sheet

Fill in `config/samples.tsv` with your sample names and paths to raw FASTQ files:

```tsv
sample	long_reads
sample1	/path/to/sample1_reads.fastq.gz
sample2	/path/to/sample2_reads.fastq.gz
```

### 2. Config file

Edit `config/config.yaml` to set:

| Parameter | Description |
|-----------|-------------|
| `outdir` | Output directory (default: `meep_pipeline/results`) |
| `human_ref` | Path to pre-built human reference minimap2 index (`.mmi`) |
| `samples` | Path to sample sheet TSV |
| `filtlong.min_length` | Minimum read length in bp |
| `filtlong.min_mean_q` | Minimum mean Phred quality score |
| `filtlong.keep_percent` | Percentage of best bases to keep |
| `flye.read_type` | Flye read type flag (e.g. `--nano-hq`) |
| `flye.genome_size` | Expected genome size (e.g. `5m`) |
| `flye.min_overlap` | Minimum overlap for Flye |
| `flye.extra_args` | Additional Flye flags (e.g. `--meta`) |
| `medaka.model` | Medaka model (e.g. `r1041_e82_400bps_hac_g632`) |
| `medaka.chunk_len` | Consensus chunk length (default: `800`) |
| `medaka.chunk_ovlp` | Overlap between chunks (default: `400`) |
| `checkm2.db` | Path to CheckM2 diamond database (`.dmnd`) |

### 3. Resources

- **Human reference index**: place or symlink your pre-built GRCh38 minimap2
  index at `meep_pipeline/resources/GRCh38.mmi` (or update `human_ref` in the
  config).
- **CheckM2 database**: place the database at
  `meep_pipeline/resources/checkm2_db/uniref100.KO.1.dmnd` (or update
  `checkm2.db` in the config).

> **Note**: The `meep_pipeline/resources/` directory is listed in `.gitignore`
> to prevent large database and reference files from being committed. You must
> create this directory locally and populate it with the required files before
> running the pipeline.

## Running the pipeline

### With conda environments (recommended)

Snakemake builds each per-tool environment automatically on first run. Using
`mamba` as the solver significantly speeds up environment creation:

```bash
snakemake --use-conda --conda-frontend mamba --cores <N>
```

Without mamba:

```bash
snakemake --use-conda --cores <N>
```

### Dry run

Preview jobs without executing:

```bash
snakemake --use-conda --cores <N> -n
```

## Output structure

```
meep_pipeline/results/
├── <sample>/
│   ├── 01_nanostat_raw/
│   ├── 02_human_depletion/
│   ├── 03_porechop/
│   ├── 04_nanostat_clean/
│   ├── 05_filtlong/
│   ├── 06_flye/
│   ├── 07_quast/            ← QUAST report for unpolished assembly
│   ├── 08_medaka/
│   ├── 09_checkm2/
│   ├── 10_quast_polished/   ← QUAST report for polished assembly
│   └── logs/
└── multiqc/
    └── multiqc_report.html  ← Aggregated QC report
### 2. Edit the configuration

Adjust `config/config.yaml` to set output paths, filtlong thresholds, Flye genome size, Medaka model, and CheckM2 database path.

### 3. Provide reference resources

Place the following files at the paths configured in `config/config.yaml` (defaults shown):

- `meepmeep/resources/GRCh38.mmi` — minimap2 index of the human reference genome
- `meepmeep/resources/checkm2_db/uniref100.KO.1.dmnd` — CheckM2 diamond database

## Running the pipeline

```bash
# Dry-run to verify the workflow
snakemake --use-apptainer --cores <N> -n

# Full run
snakemake --use-apptainer --cores <N>
```

> **Note:** On older Snakemake 7.x installations use `--use-singularity` instead of `--use-apptainer`.

## Building containers locally

All Dockerfiles use the repository root as the build context so that the `envs/` YAML files are accessible:

```bash
docker build -f containers/longread_env/Dockerfile   -t meepmeep-longread-env  .
docker build -f containers/assembly_tools/Dockerfile -t meepmeep-assembly-tools .
docker build -f containers/medaka/Dockerfile         -t meepmeep-medaka        .
docker build -f containers/checkm2/Dockerfile        -t meepmeep-checkm2       .
```
