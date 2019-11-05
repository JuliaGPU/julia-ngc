ARG IMAGE=nvidia/cuda:10.0-cudnn7-devel-ubuntu18.04
FROM $IMAGE

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

COPY Project.toml Manifest.toml /usr/local/share/julia/environments/v1.2/

RUN JULIA_DEPOT_PATH=/usr/local/share/julia \
    julia -e 'using Pkg; Pkg.instantiate(); Pkg.API.precompile()' && \
    # work around JuliaPackaging/BinaryProvider.jl#183
    chown root:root -R /usr/local/share/julia/packages/*/*/deps/usr && \
    # work around JuliaPackaging/BinaryBuilder.jl#447
    chmod 755 /usr/local/share/julia/packages/*/*/deps/usr && \
    # work around JuliaLang/julia#25971
    chmod 644 /usr/local/share/julia/compiled/*/*/*.ji && \
    # fix package folder permissions
    chmod 755 /usr/local/share/julia/packages/*/*


# user environment

# we use a single folder, /data, as the user depot regardless of the actual user
# (i.e., to be compatible with `docker run --user`, which might not have a $HOME)

RUN mkdir -m 0777 /data
ENV JULIA_DEPOT_PATH=/data:/usr/local/share/julia

ENV JULIA_HISTORY=/data/logs/repl_history.jl

WORKDIR "/workspace"
COPY examples /workspace/examples

ENTRYPOINT ["/usr/local/bin/julia"]
