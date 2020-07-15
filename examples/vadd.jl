using CUDA
using Test

function vadd(a, b, c)
    i = (blockIdx().x-1) * blockDim().x + threadIdx().x
    c[i] = a[i] + b[i]
    return
end

# generate CPU data
dims = (3,4)
a = round.(rand(Float32, dims) * 100)
b = round.(rand(Float32, dims) * 100)
c = similar(a)

# upload to GPU
d_a = CuArray(a)
d_b = CuArray(b)
d_c = CuArray(c)

len = prod(dims)
@cuda threads=len vadd(d_a, d_b, d_c)

# download and verify
c = Array(d_c)
@test a+b ≈ c
