# Julia for NGC

This repository provides a Docker recipe suitable for running the latest version
of Julia and its CUDA GPU stack. It has been developed for use on NGC, NVIDIA's
catalog of Docker containers, but can be used with plain Docker as well.

The container recipe is based on NVIDIA's Ubuntu images with CUDA pre-installed,
and is currently hard-coded for use on x86_64 hosts.


## Usage

```
$ docker build -t ngc .
$ docker run --gpus=all -it --rm ngc
```

Note that the `--gpus=all` argument requires a sufficiently recent version of
Docker, as well as the NVIDIA Container Runtime to be installed and configured.

To test CUDA.jl, it is recommended to launch Julia with multiple threads. This
can be done by passing `-tauto` to the container invocation, e.g., `docker run
--gpus=all -it --rm ngc -tauto`.


## Updating

To update the software used by this container, note that both Julia and CUDA.jl
are pinned to specific versions.


### Julia

Edit the `Dockerfile` and change the `JULIA_RELEASE` and `JULIA_VERSION`
arguments at the top. Then edit the `Project.toml` to reflect these changes.

### Packages

The repository contains a `Project.toml` listing the packages that will be
installed, currently only CUDA.jl, and a `Manifest.toml` locking the specific
versions that will be used. To update this environment, use Julia on your host
system:

```
$ julia --project
$ pkg> update
```

Make sure you use the same version of Julia as will be used in the container, or
incompatible package versions may be selected.
