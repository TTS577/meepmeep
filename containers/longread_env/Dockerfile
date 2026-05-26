# ── meep longread environment ────────────────────────────────────────────────
# Tools: minimap2, samtools, porechop, filtlong, flye, nanostat
# Build from the repository root:
#   docker build -f containers/longread_env/Dockerfile -t meepmeep-longread-env .
FROM mambaorg/micromamba:1.5.8-jammy

LABEL org.opencontainers.image.title="meepmeep-longread-env"
LABEL org.opencontainers.image.description="meepmeep pipeline – longread QC, human depletion, adapter trimming, assembly"
LABEL org.opencontainers.image.source="https://github.com/TTS577/meepmeep"

USER root
RUN apt-get update && apt-get install -y --no-install-recommends \
        procps \
        bash \
    && rm -rf /var/lib/apt/lists/*

USER $MAMBA_USER
COPY --chown=$MAMBA_USER:$MAMBA_USER envs/meepmeep-longread_env.yaml /tmp/env.yaml
RUN micromamba install -y -n base -f /tmp/env.yaml \
    && micromamba clean --all --yes

ENV PATH="/opt/conda/bin:$PATH"
