load("@kustomize.bzl", "kustomize")
load("@rules_img//img:image.bzl", "image_manifest")

# Build an OCI image from Alpine base
image_manifest(
    name = "app_image",
    base = select({
        "@platforms//cpu:arm64": "@alpine_linux_arm64",
        "@platforms//cpu:x86_64": "@alpine_linux_amd64",
    }),
)

OCI_REGISTRY = "localhost:5000"
OCI_REPOSITORY_PREFIX = "example"

# Build kustomize manifests with image substitution.
#
# The `images` dict maps YAML image names to either:
#   - Bazel image targets (labels starting with // : or @)
#     → built, pushed to registry, digest substituted
#   - External image references (plain strings)
#     → passed through as-is via `kustomize edit set image`
kustomize(
    name = "k8s",
    srcs = glob(["k8s/**"]),
    images = {
        # External image — used as-is in manifests
        "redis": "redis:7.4-alpine",
        # Bazel image target — built, pushed, digest substituted
        "app": ":app_image",
    },
    registry = OCI_REGISTRY,
    repository_prefix = OCI_REPOSITORY_PREFIX,
)

# Generated targets:
#   :k8s          — rendered manifests with image digests
#   :k8s_push     — multi_deploy target that pushes all Bazel images
#   :k8s_app_push — individual push target for the app image

# For production use with a real registry:
# genrule(
#     name = "image_tags",
#     outs = ["image_tags.txt"],
#     cmd = "echo latest > $@",
# )
