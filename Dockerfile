FROM nvidia/cuda:10.0-cudnn7-devel-ubuntu18.04

# julia

RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive \
    apt-get install --yes --no-install-recommends \
                    # basic stuff
                    curl ca-certificates && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

RUN curl -s -L https://julialang-s3.julialang.org/bin/linux/x64/1.2/julia-1.2.0-linux-x86_64.tar.gz | \
    tar -C /usr/local -x -z --strip-components=1 -f -


# system-wide packages

# versioned packages for reproducibility
RUN JULIA_DEPOT_PATH=/usr/local/share/julia \
    julia -e 'using Pkg; \
              Pkg.add([PackageSpec(name="CUDAapi",      rev="v1.1.0"), \
                       PackageSpec(name="CUDAdrv",      rev="v3.1.0"), \
                       PackageSpec(name="CUDAnative",   rev="v2.3.0"), \
                       PackageSpec(name="CuArrays",     rev="v1.2.1")]);'


# user environment

# we use a single folder, /data, as the user depot regardless of the actual user
# (i.e., to be compatible with `docker run --user`, which might not have a $HOME)
#
# the actual modification of DEPOT_PATH happens in startup.jl

VOLUME ["/data"]

ENV JULIA_HISTORY=/data/logs/repl_history.jl

COPY startup.jl /usr/local/etc/julia/startup.jl

WORKDIR "/workspace"
COPY examples /workspace/examples

ENTRYPOINT ["/usr/local/bin/julia"]
