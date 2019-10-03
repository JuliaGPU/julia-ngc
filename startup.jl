# first-time setup
flag = "/data/.initialized"
if !isfile(flag)
    println("""
        Performing first time setup, this might take a while...
        To avoid this step, and/or install additional packages, please make /data persistent.
        """)

    # create the user depot
    ## use the build-time registry to avoid a git clone when installing a package
    cp("/usr/local/share/julia/registries",   "/data/registries")
    ## copy the environment as the full stack isn't visualized (JuliaLang/Pkg.jl#961)
    cp("/usr/local/share/julia/environments", "/data/environments")

    # precompile packages for improved package loading times
    using Pkg
    Pkg.API.precompile()

    touch(flag)
end

# check if we have CUDA and a GPU
using CUDAapi
if !CUDAapi.has_cuda()
    println("Could not detect CUDA! GPU functionality will be unavailable.")
    println()
elseif !CUDAapi.has_cuda_gpu()
    println("Could not detect a CUDA GPU! GPU functionality will be unavailable.")
    println()
end
