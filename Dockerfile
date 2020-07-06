ARG IMAGE=nvidia/cuda:10.2-cudnn7-devel-ubuntu18.04
FROM $IMAGE

COPY Project.toml Manifest.toml /usr/local/share/julia/environments/v1.4/


# julia

RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive \
    apt-get install --yes --no-install-recommends \
                    # basic stuff
                    curl ca-certificates && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# NOTE: this extracts the Julia version (assumed major.minor.patch) from the
#       Project.toml to keep it in sync with the GitHub Action workflow.

RUN VERSION=$(grep '^julia = ' /usr/local/share/julia/environments/v1.4/Project.toml | grep -o '".*"' | cut -d '"' -f2) && \
    RELEASE=$(echo $VERSION | cut -d '.' -f 1,2 ) && \
    curl -s -L https://julialang-s3.julialang.org/bin/linux/x64/${RELEASE}/julia-${VERSION}-linux-x86_64.tar.gz | \
    tar -C /usr/local -x -z --strip-components=1 -f -


# system-wide packages

RUN JULIA_DEPOT_PATH=/usr/local/share/julia \
    julia -e 'using Pkg; Pkg.instantiate(); Pkg.API.precompile()'

# generate the device runtime library for all known and supported devices
RUN JULIA_DEPOT_PATH=/usr/local/share/julia CUDA_INIT_SILENT=true \
    julia -e 'using CUDAnative; CUDAnative.load_runtime.([v"3.0", v"3.2", v"3.5", v"3.7", \
                                                          v"5.0", v"5.2", v"5.3", \
                                                          v"6.0", v"6.1", v"6.2", \
                                                          v"7.0"])'


# user environment

# we use a single folder, /data, as the user depot regardless of the actual user
# (i.e., to be compatible with `docker run --user`, which might not have a $HOME)

RUN mkdir -m 0777 /data
ENV JULIA_DEPOT_PATH=/data:/usr/local/share/julia

ENV JULIA_HISTORY=/data/logs/repl_history.jl

ENV JULIA_CUDA_USE_BINARYBUILDER=false

WORKDIR "/workspace"
COPY examples /workspace/examples

ENTRYPOINT ["/usr/local/bin/julia"]
