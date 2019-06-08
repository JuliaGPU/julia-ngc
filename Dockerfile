FROM nvidia/cuda:10.0-cudnn7-devel-ubuntu18.04

# Julia version 1.1.1
RUN apt-get update -y && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        tar \
        wget && \
    rm -rf /var/lib/apt/lists/*
RUN mkdir -p /var/tmp && wget -q -nc --no-check-certificate -P /var/tmp https://julialang-s3.julialang.org/bin/linux/x64/1.1/julia-1.1.1-linux-x86_64.tar.gz && \
    mkdir -p /var/tmp && tar -x -f /var/tmp/julia-1.1.1-linux-x86_64.tar.gz -C /var/tmp -z && \
    cp -a /var/tmp/julia-1.1.1 /usr/local/julia && \
    JULIA_DEPOT_PATH=~/.julia-ngc /usr/local/julia/bin/julia -e 'using Pkg; Pkg.add([PackageSpec(name="CUDAnative", rev="v2.1.3"), PackageSpec(name="CuArrays", rev="v1.0.2"), PackageSpec(name="GPUArrays", rev="v0.7.2")])' && \
    echo "/usr/local/julia/lib" >> /etc/ld.so.conf.d/hpccm.conf && ldconfig && \
    rm -rf /var/tmp/julia-1.1.1-linux-x86_64.tar.gz /var/tmp/julia-1.1.1
ENV JULIA_DEPOT_PATH=~/.julia-ngc \
    PATH=/usr/local/julia/bin:$PATH

COPY examples /workspace/examples

COPY entrypoint.sh /usr/local/bin/entrypoint.sh

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]


