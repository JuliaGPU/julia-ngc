# replace the user depot path (can't do this with JULIA_DEPOT_PATH
# or it forgets the other entries, such as /usr/local/share/julia)
DEPOT_PATH[1] = "/data"

# check if we have CUDA and a GPU
using CUDAapi
if !CUDAapi.has_cuda()
    println("Could not detect CUDA! GPU functionality will be unavailable.")
    println()
elseif !CUDAapi.has_cuda_gpu()
    println("Could not detect a CUDA GPU! GPU functionality will be unavailable.")
    println()
end

# precompile packages for improved package loading times
# TODO: do we want to do this? lazy-loading could be fine too, but maybe the NGC UI supports
#       volumes (does __pycache__ persist?), or ideally doing this step ahead of time
#       for every node it'll run on (`docker run ... -e exit()` works to trigger this).
flag = "/data/.initialized"
if !isfile(flag)
    println("""
        Performing first time setup, this might take a while...
        To avoid this step, and/or install additional packages, please make /data persistent.
        """)
    touch(flag)

    using Pkg
    Pkg.API.precompile()
end
