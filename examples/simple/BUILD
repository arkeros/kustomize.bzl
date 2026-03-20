load("@kubeconform.bzl", "kubeconform_test")
load("@kustomize.bzl", "kustomize", "kustomize_binary")

# Basic kustomize build (no image substitution)
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

# Image substitution example (commented out — requires rules_img image targets)
#
# The `kustomize` macro accepts both Bazel image targets and external
# image references. Bazel targets are pushed to the registry with their
# digest substituted into the manifests. External references are passed
# through as-is via `kustomize edit set image`.
#
# OCI_REGISTRY = "europe-southwest1-docker.pkg.dev"
# OCI_REPOSITORY_PREFIX = "my-project/my-repo"
#
# kustomize(
#     name = "k8s",
#     srcs = glob(["base/**"]),
#     images = {
#         # External image — used as-is in manifests
#         "redis": "redis:8.4.2",
#         # Bazel image targets — built, pushed, digest substituted
#         "nats": "//nats:image_nonroot",
#         "my-app/api": "//my-app/api:image_nonroot",
#         "my-app/web": "//my-app/web:image_nonroot",
#         "my-app/worker": "//my-app/worker:image_nonroot",
#     },
#     registry = OCI_REGISTRY,
#     repository_prefix = OCI_REPOSITORY_PREFIX,
#     deps = [
#         "//my-app/k8s/base",
#     ],
# )
#
# This generates:
#   :k8s              — rendered manifests with image digests
#   :k8s_push         — multi_deploy target that pushes all Bazel images
#   :k8s_my_app_api_push — individual push target per image

alias(
    name = "kubectl",
    actual = "@multitool//tools/kubectl",
)
