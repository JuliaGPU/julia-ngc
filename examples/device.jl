using CUDAdrv

println("Available GPUs:")
for dev in devices()
    println("- ", CUDAdrv.name(dev))
end
