load("@kubeconform.bzl", "kubeconform_test")
load("@kustomize.bzl", "kustomize_binary")

kustomize_binary(
    name = "prod_manifests",
    srcs = glob([
        "base/**",
        "overlays/prod/**",
    ]),
    kustomization_dir = "overlays/prod",
)

kubeconform_test(
    name = "validate_prod_test",
    data = [":prod_manifests"],
    kubernetes_version = "1.29.0",
)

alias(
    name = "kubectl",
    actual = "@multitool//tools/kubectl",
)
