# Note that this script can accept some limited command-line arguments, run
# `julia build_tarballs.jl --help` to see a usage message.
using BinaryBuilder, Pkg

const YGGDRASIL_DIR = "../../.."
include(joinpath(YGGDRASIL_DIR, "fancy_toys.jl"))
include(joinpath(YGGDRASIL_DIR, "platforms", "cuda.jl"))

name = "ONNXRuntime_CUDA"
version = v"1.20.1"

# Cf. https://onnxruntime.ai/docs/execution-providers/CUDA-ExecutionProvider.html#requirements
# Cf. https://onnxruntime.ai/docs/execution-providers/TensorRT-ExecutionProvider.html#requirements
# Cf. https://github.com/microsoft/onnxruntime/blob/v1.20.1/tools/ci_build/github/azure-pipelines/stages/py-cuda-packaging-stage.yml#L35
cuda_versions = [
    v"11.8",
    v"12.2",
]

cudnn_versions = Dict(
    v"11.8" => v"8.y11",
    v"12.2" => v"9.y12",
)

tensorrt_version = v"10.5.z"

tensorrt_compat = string(tensorrt_version.major)

include(joinpath(@__DIR__, "..", "common.jl"))

# Override the default sources
append!(sources, [
    ArchiveSource("https://github.com/microsoft/onnxruntime/releases/download/v$version/onnxruntime-win-x64-gpu-$version.zip", "3e9658d4aa7c21b3f5cbb5a7ce0356184f3c183c317b52f9cfff23a3f079634e"; unpack_target="onnxruntime-x86_64-w64-mingw32-cuda"),
    # aarch64-linux-gnu binaries for NVIDIA Jetson from NVIDIA-managed Jetson Zoo: https://elinux.org/Jetson_Zoo#ONNX_Runtime
    FileSource("https://nvidia.box.com/shared/static/jy7nqva7l88mq9i8bw3g3sklzf4kccn2.whl", "a608b7a4a4fc6ad5c90d6005edbfe0851847b991b08aafff4549bbbbdb938bf6"; filename = "onnxruntime-aarch64-linux-gnu-cuda.whl"),
])

# Override the default platforms
platforms = CUDA.supported_platforms()
platforms = expand_cxxstring_abis(platforms; skip=!Sys.islinux)

# Override the default products
append!(products, [
    LibraryProduct(["libonnxruntime_providers_cuda", "onnxruntime_providers_cuda"], :libonnxruntime_providers_cuda; dont_dlopen=true),
    LibraryProduct(["libonnxruntime_providers_shared", "onnxruntime_providers_shared"], :libonnxruntime_providers_shared),
    LibraryProduct(["libonnxruntime_providers_tensorrt", "onnxruntime_providers_tensorrt"], :libonnxruntime_providers_tensorrt; dont_dlopen=true),
])

append!(dependencies, [
    Dependency("TensorRT_jll", tensorrt_version; compat = tensorrt_compat),
    Dependency("Zlib_jll"),
])

builds = []
for platform in platforms
    should_build_platform(platform) || continue
    cudnn_version = cudnn_versions[platform["cuda"]]
    additional_deps = append(
        CUDA.required_dependencies(platform, static_sdk = true),
        [
            Dependency("CUDNN_jll"; compat = string(cudnn_version.major)),
        ]
    )
    push!(builds, (; platforms=[platform], dependencies=[dependencies; additional_deps]))
end

# don't allow `build_tarballs` to override platform selection based on ARGS.
# we handle that ourselves by calling `should_build_platform`
non_platform_ARGS = filter(arg -> startswith(arg, "--"), ARGS)

# `--register` should only be passed to the latest `build_tarballs` invocation
non_reg_ARGS = filter(arg -> arg != "--register", non_platform_ARGS)

for (i, build) in enumerate(builds)
    build_tarballs(i == lastindex(builds) ? non_platform_ARGS : non_reg_ARGS,
                   name, version, sources, script,
                   build.platforms, products, build.dependencies;
                   augment_platform_block = CUDA.augment,
                   julia_compat = "1.6",
                   lazy_artifacts = true,
                   preferred_gcc_version = v"8")
end
