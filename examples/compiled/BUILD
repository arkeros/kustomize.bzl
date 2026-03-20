load("@kustomize.bzl", "kustomize_binary", "kustomize_toolchain")

# Custom toolchain using kustomize compiled from Go source
kustomize_toolchain(
    name = "compiled_kustomize_toolchain",
    kustomize = "@io_k8s_sigs_kustomize_kustomize_v5//:v5",
    visibility = ["//visibility:public"],
)

toolchain(
    name = "kustomize_toolchain",
    toolchain = ":compiled_kustomize_toolchain",
    toolchain_type = "@kustomize.bzl//:toolchain_type",
)

# Use the compiled toolchain to build manifests
kustomize_binary(
    name = "prod_manifests",
    srcs = glob([
        "base/**",
        "overlays/prod/**",
    ]),
    kustomization_dir = "overlays/prod",
)
