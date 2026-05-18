import pandas as pd
from pathlib import Path

# ── Config ────────────────────────────────────────────────────────────────────
configfile: "config/config.yaml"

# ── Container images (GHCR) ───────────────────────────────────────────────────
CONTAINER_LONGREAD  = "docker://ghcr.io/tts577/meepmeep/longread-env:latest"
CONTAINER_ASSEMBLY  = "docker://ghcr.io/tts577/meepmeep/assembly-tools:latest"
CONTAINER_MEDAKA    = "docker://ghcr.io/tts577/meepmeep/medaka:latest"
CONTAINER_CHECKM2   = "docker://ghcr.io/tts577/meepmeep/checkm2:latest"

OUTDIR    = config.get("outdir", "meepmeep/results")
HUMAN_REF = config.get("human_ref", "meepmeep/resources/GRCh38.mmi")

# Ensure process substitutions (tee >(…)) work correctly
shell.executable("/bin/bash")

# ── Sample sheet ──────────────────────────────────────────────────────────────
samples_df = pd.read_csv(config["samples"], sep="\t", index_col="sample")
SAMPLES    = samples_df.index.tolist()

def get_raw_reads(wildcards):
    return samples_df.loc[wildcards.sample, "long_reads"]

# ── Helper: collect all MultiQC input logs ────────────────────────────────────
def multiqc_inputs(wildcards):
    inputs = []
    for s in SAMPLES:
        inputs += [
            f"{OUTDIR}/{s}/01_nanostat_raw/{s}_NanoStats.txt",
            f"{OUTDIR}/{s}/04_nanostat_clean/{s}_NanoStats.txt",
            f"{OUTDIR}/{s}/06_flye/assembly_info.txt",
            f"{OUTDIR}/{s}/09_checkm2/quality_report.tsv",
        ]
    return inputs

# ── Target rule ───────────────────────────────────────────────────────────────
rule all:
    input:
        expand("{outdir}/{sample}/07_quast/report.tsv",           outdir=OUTDIR, sample=SAMPLES),
        expand("{outdir}/{sample}/09_checkm2/quality_report.tsv", outdir=OUTDIR, sample=SAMPLES),
        f"{OUTDIR}/multiqc/multiqc_report.html",

# ══════════════════════════════════════════════════════════════════════════════
# STEP 1 — Raw read QC with NanoStat
# ══════════════════════════════════════════════════════════════════════════════
rule nanostat_raw:
    input:
        reads = get_raw_reads,
    output:
        stats = "{outdir}/{sample}/01_nanostat_raw/{sample}_NanoStats.txt",
    params:
        outdir = "{outdir}/{sample}/01_nanostat_raw",
        name   = "{sample}_NanoStats.txt",
    threads: 4
    container: CONTAINER_LONGREAD
    log: "{outdir}/{sample}/logs/nanostat_raw.log"
    shell:
        """
        NanoStat \
            --fastq {input.reads} \
            --outdir {params.outdir} \
            --name {params.name} \
            --threads {threads} \
            --N50 \
            2> {log}
        """

# ══════════════════════════════════════════════════════════════════════════════
# STEP 2 — Human read depletion with minimap2 + samtools
# ══════════════════════════════════════════════════════════════════════════════
rule human_depletion_minimap2:
    input:
        reads     = get_raw_reads,
        human_ref = HUMAN_REF,
    output:
        depleted = "{outdir}/{sample}/02_human_depletion/{sample}_nonhuman.fastq.gz",
        stats    = "{outdir}/{sample}/02_human_depletion/{sample}_flagstat.txt",
    threads: 16
    container: CONTAINER_LONGREAD
    log: "{outdir}/{sample}/logs/human_depletion.log"
    shell:
        """
        minimap2 \
            -ax map-ont \
            -t {threads} \
            --secondary=no \
            {input.human_ref} \
            {input.reads} \
        2> {log} \
        | samtools view -b -@ {threads} \
        | tee >(samtools flagstat -@ {threads} - > {output.stats}) \
        | samtools view -b -f 4 -@ {threads} - \
        | samtools fastq -@ {threads} - \
        | gzip > {output.depleted}
        """

# ══════════════════════════════════════════════════════════════════════════════
# STEP 3 — Adapter trimming with Porechop
# ══════════════════════════════════════════════════════════════════════════════
rule porechop:
    input:
        reads = "{outdir}/{sample}/02_human_depletion/{sample}_nonhuman.fastq.gz",
    output:
        reads = "{outdir}/{sample}/03_porechop/{sample}_trimmed.fastq.gz",
    threads: 8
    container: CONTAINER_LONGREAD
    log: "{outdir}/{sample}/logs/porechop.log"
    shell:
        """
        porechop \
            -i {input.reads} \
            -o {output.reads} \
            --threads {threads} \
            2> {log}
        """

# ══════════════════════════════════════════════════════════════════════════════
# STEP 4 — Post-depletion/trim read QC with NanoStat
# ══════════════════════════════════════════════════════════════════════════════
rule nanostat_clean:
    input:
        reads = "{outdir}/{sample}/03_porechop/{sample}_trimmed.fastq.gz",
    output:
        stats = "{outdir}/{sample}/04_nanostat_clean/{sample}_NanoStats.txt",
    params:
        outdir = "{outdir}/{sample}/04_nanostat_clean",
        name   = "{sample}_NanoStats.txt",
    threads: 4
    container: CONTAINER_LONGREAD
    log: "{outdir}/{sample}/logs/nanostat_clean.log"
    shell:
        """
        NanoStat \
            --fastq {input.reads} \
            --outdir {params.outdir} \
            --name {params.name} \
            --threads {threads} \
            --N50 \
            2> {log}
        """

# ══════════════════════════════════════════════════════════════════════════════
# STEP 5 — Read quality filtering with Filtlong
# ══════════════════════════════════════════════════════════════════════════════
rule filtlong:
    input:
        reads = "{outdir}/{sample}/03_porechop/{sample}_trimmed.fastq.gz",
    output:
        reads = "{outdir}/{sample}/05_filtlong/{sample}_filtered.fastq.gz",
    params:
        min_length   = config["filtlong"]["min_length"],
        min_mean_q   = config["filtlong"]["min_mean_q"],
        keep_percent = config["filtlong"]["keep_percent"],
    container: CONTAINER_LONGREAD
    log: "{outdir}/{sample}/logs/filtlong.log"
    shell:
        """
        filtlong \
            --min_length {params.min_length} \
            --min_mean_q {params.min_mean_q} \
            --keep_percent {params.keep_percent} \
            {input.reads} \
        2> {log} \
        | gzip > {output.reads}
        """

# ══════════════════════════════════════════════════════════════════════════════
# STEP 6 — De novo assembly with Flye
# ══════════════════════════════════════════════════════════════════════════════
rule flye:
    input:
        reads = "{outdir}/{sample}/05_filtlong/{sample}_filtered.fastq.gz",
    output:
        assembly = "{outdir}/{sample}/06_flye/assembly.fasta",
        info     = "{outdir}/{sample}/06_flye/assembly_info.txt",
    params:
        read_type   = config["flye"]["read_type"],
        genome_size = config["flye"]["genome_size"],
        min_overlap = config["flye"]["min_overlap"],
        extra       = config["flye"]["extra_args"],
        outdir      = "{outdir}/{sample}/06_flye",
    threads: 16
    container: CONTAINER_LONGREAD
    log: "{outdir}/{sample}/logs/flye.log"
    shell:
        """
        flye \
            {params.read_type} {input.reads} \
            --out-dir {params.outdir} \
            --genome-size {params.genome_size} \
            --min-overlap {params.min_overlap} \
            --threads {threads} \
            {params.extra} \
            2> {log}
        """

# ══════════════════════════════════════════════════════════════════════════════
# STEP 7 — Assembly QC with QUAST
# ══════════════════════════════════════════════════════════════════════════════
rule quast:
    input:
        assembly = "{outdir}/{sample}/06_flye/assembly.fasta",
    output:
        report = "{outdir}/{sample}/07_quast/report.tsv",
    params:
        outdir = "{outdir}/{sample}/07_quast",
    threads: 4
    container: CONTAINER_ASSEMBLY
    log: "{outdir}/{sample}/logs/quast.log"
    shell:
        """
        quast.py \
            {input.assembly} \
            --output-dir {params.outdir} \
            --threads {threads} \
            2> {log}
        """

# ══════════════════════════════════════════════════════════════════════════════
# STEP 8 — Long-read polishing with Medaka
# ══════════════════════════════════════════════════════════════════════════════
rule medaka:
    input:
        reads    = "{outdir}/{sample}/05_filtlong/{sample}_filtered.fastq.gz",
        assembly = "{outdir}/{sample}/06_flye/assembly.fasta",
    output:
        assembly = "{outdir}/{sample}/08_medaka/consensus.fasta",
    params:
        model  = config["medaka"]["model"],
        outdir = "{outdir}/{sample}/08_medaka",
    threads: 8
    container: CONTAINER_MEDAKA
    log: "{outdir}/{sample}/logs/medaka.log"
    shell:
        """
        medaka_consensus \
            -i {input.reads} \
            -d {input.assembly} \
            -o {params.outdir} \
            -m {params.model} \
            -t {threads} \
            2> {log}
        """

# ══════════════════════════════════════════════════════════════════════════════
# STEP 9 — Genome completeness & contamination with CheckM2
# ══════════════════════════════════════════════════════════════════════════════
rule checkm2:
    input:
        assembly = "{outdir}/{sample}/08_medaka/consensus.fasta",
    output:
        report = "{outdir}/{sample}/09_checkm2/quality_report.tsv",
    params:
        outdir = "{outdir}/{sample}/09_checkm2",
        db     = config["checkm2"]["db"],
    threads: 8
    container: CONTAINER_CHECKM2
    log: "{outdir}/{sample}/logs/checkm2.log"
    shell:
        """
        checkm2 predict \
            --input {input.assembly} \
            --output-directory {params.outdir} \
            --database_path {params.db} \
            --threads {threads} \
            --force \
            2> {log}
        """

# ══════════════════════════════════════════════════════════════════════════════
# STEP 10 — Aggregate all QC with MultiQC
# ══════════════════════════════════════════════════════════════════════════════
rule multiqc:
    input:
        multiqc_inputs,
    output:
        report = f"{OUTDIR}/multiqc/multiqc_report.html",
    params:
        indir  = OUTDIR,
        outdir = f"{OUTDIR}/multiqc",
    container: CONTAINER_ASSEMBLY
    log: f"{OUTDIR}/logs/multiqc.log"
    shell:
        """
        multiqc \
            {params.indir} \
            --outdir {params.outdir} \
            --force \
            2> {log}
        """
