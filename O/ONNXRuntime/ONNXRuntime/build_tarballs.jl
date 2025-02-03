# Note that this script can accept some limited command-line arguments, run
# `julia build_tarballs.jl --help` to see a usage message.
using BinaryBuilder, Pkg

name = "ONNXRuntime"
version = v"1.20.1"

include(joinpath(@__DIR__, "..", "common.jl"))

# Override the default sources
append!(sources, [
    ArchiveSource("https://github.com/microsoft/onnxruntime/releases/download/v$version/onnxruntime-win-x64-$version.zip", "78d447051e48bd2e1e778bba378bec4ece11191c9e538cf7b2c4a4565e8f5581"; unpack_target="onnxruntime-x86_64-w64-mingw32"),
    ArchiveSource("https://github.com/microsoft/onnxruntime/releases/download/v$version/onnxruntime-win-x86-$version.zip", "e4364d3b4a56847b87141529019f2faa04699bf732e075a85f112e9c049309cf"; unpack_target="onnxruntime-i686-w64-mingw32"),
])

build_tarballs(ARGS, name, version, sources, script,
               platforms, products, dependencies;
               julia_compat = "1.6",
               preferred_gcc_version = v"8")
