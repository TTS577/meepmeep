# ── meep checkm2 environment ─────────────────────────────────────────────────
# Tools: checkm2
# Build from the repository root:
#   docker build -f containers/checkm2/Dockerfile -t meep-checkm2 .
FROM mambaorg/micromamba:1.5.8-jammy

LABEL org.opencontainers.image.title="meepmeep-checkm2"
LABEL org.opencontainers.image.description="meepmeep pipeline – genome completeness & contamination estimation (CheckM2)"
LABEL org.opencontainers.image.source="https://github.com/TTS577/meepmeep"

USER root
RUN apt-get update && apt-get install -y --no-install-recommends \
        procps \
        bash \
    && rm -rf /var/lib/apt/lists/*

USER $MAMBA_USER
COPY --chown=$MAMBA_USER:$MAMBA_USER envs/meepmeep_checkm2.yaml /tmp/env.yaml
RUN micromamba install -y -n base -f /tmp/env.yaml \
    && micromamba clean --all --yes

ENV PATH="/opt/conda/bin:$PATH"
