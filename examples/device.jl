using CUDA

println("Available GPUs:")
for dev in devices()
    println("- ", CUDA.name(dev))
end
