load("@kustomize.bzl", "kustomize")
load("@rules_oci//oci:defs.bzl", "oci_image")

# Build an OCI image using rules_oci
oci_image(
    name = "app_image",
    base = "@distroless_static_linux_amd64",
)

OCI_REGISTRY = "localhost:5000"
OCI_REPOSITORY_PREFIX = "example"

# Build kustomize manifests with rules_oci image substitution.
#
# The `oci_images` dict maps YAML image names to rules_oci image targets.
# The macro automatically references the .digest sub-target to pin
# images by digest in the rendered manifests. Push is handled separately
# by rules_oci's oci_push — no push targets are created here.
kustomize(
    name = "k8s",
    srcs = glob(["k8s/**"]),
    # External image — used as-is in manifests
    images = {
        "redis": "redis:7.4-alpine",
    },
    manifest_registry = OCI_REGISTRY,
    # rules_oci image target — digest substituted automatically
    oci_images = {
        "app": ":app_image",
    },
    repository_prefix = OCI_REPOSITORY_PREFIX,
)

# Generated targets:
#   :k8s — rendered manifests with image digests
#
# Note: unlike the rules_img `images` example, no _push targets are
# created for oci_images. Use rules_oci's oci_push to push images.
