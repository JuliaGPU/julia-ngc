ARG IMAGE=nvidia/cuda:12.1.1-devel-ubuntu20.04
FROM $IMAGE

ARG JULIA_RELEASE=1.9
ARG JULIA_VERSION=1.9.0-rc3


# julia

RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive \
    apt-get install --yes --no-install-recommends \
    # basic stuff
    curl ca-certificates nano && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

RUN curl -s -L https://julialang-s3.julialang.org/bin/linux/x64/${JULIA_RELEASE}/julia-${JULIA_VERSION}-linux-x86_64.tar.gz | \
    tar -C /usr/local -x -z --strip-components=1 -f -


# system-wide packages

COPY Project.toml Manifest.toml LocalPreferences.toml /usr/local/share/julia/environments/v${JULIA_RELEASE}/

RUN JULIA_DEPOT_PATH=/usr/local/share/julia \
    julia -e 'using Pkg; Pkg.instantiate(); Pkg.API.precompile()'

# generate the device runtime library for all known and supported devices
# XXX: this doesn't precompile into the system depot anymore
RUN JULIA_DEPOT_PATH=/usr/local/share/julia \
    julia -e 'using CUDA; CUDA.precompile_runtime()'

# the system depot contains precompiled packages, but its global environment cannot be
# active at the same time of the user environment. we solve this by using a startup script
# that will initialize the user depot with the Project and Manifest from the system depot.
# however, for that script to run, we need to start with only the system depot active.
ENV JULIA_DEPOT_PATH=/usr/local/share/julia
COPY startup.jl /usr/local/share/julia/config/


# user environment

# we use a single folder, /data, as the user depot regardless of the actual user
# (i.e., to be compatible with `docker run --user`, which might not have a $HOME)

RUN mkdir -m 0777 /data

ENV JULIA_HISTORY=/data/logs/repl_history.jl

WORKDIR "/workspace"
COPY examples /workspace/examples

ENTRYPOINT ["/usr/local/bin/julia"]
