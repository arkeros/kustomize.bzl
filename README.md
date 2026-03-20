# kustomize.bzl

Bazel rules for building Kubernetes manifests with [kustomize](https://kustomize.io/).

## Features

- Build kustomizations hermetically with Bazel
- Image substitution (Bazel image targets and external references)
- Template variable substitution (`${VAR}` syntax)
- Auto-detection of `kustomization.yaml` directories
- Integration with [rules_img](https://github.com/bazel-contrib/rules_img) for image push
- Cross-platform support (Linux, macOS, Windows)

## Setup

Add to your `MODULE.bazel`:

```starlark
bazel_dep(name = "kustomize.bzl", version = "0.0.0")
git_override(
    module_name = "kustomize.bzl",
    remote = "https://github.com/arkeros/kustomize.bzl.git",
    commit = "...",
)

kustomize = use_extension("@kustomize.bzl//:extensions.bzl", "kustomize")
kustomize.toolchain()
use_repo(kustomize, "kustomize_toolchains")
register_toolchains("@kustomize_toolchains//:all")
```

## Usage

### Basic kustomize build

```starlark
load("@kustomize.bzl", "kustomize_binary")

kustomize_binary(
    name = "prod_manifests",
    srcs = glob([
        "base/**",
        "overlays/prod/**",
    ]),
    kustomization_dir = "overlays/prod",
)
```

### Kustomize library (composable)

```starlark
load("@kustomize.bzl", "kustomize_library")

kustomize_library(
    name = "base",
    srcs = glob(["base/**"]),
)

kustomize_binary(
    name = "prod",
    srcs = glob(["overlays/prod/**"]),
    deps = [":base"],
)
```

### With image substitution

```starlark
load("@kustomize.bzl", "kustomize")

kustomize(
    name = "manifests",
    srcs = glob(["k8s/**"]),
    images = {
        "my-app": "//app:image",         # Bazel image target
        "redis": "redis:7.4-alpine",     # External reference
    },
    registry = "localhost:5000",
)
```

### With template substitutions

```starlark
kustomize_binary(
    name = "manifests",
    srcs = glob(["k8s/**"]),
    substitutions = {
        "${HOSTNAME}": "example.com",
        "${REPLICAS}": "3",
    },
)
```

### Attributes

| Attribute | Type | Description |
|-----------|------|-------------|
| `srcs` | label_list | Source files (required) |
| `deps` | label_list | Dependencies (other kustomize_library targets, helm charts, etc.) |
| `kustomization_dir` | string | Directory containing kustomization.yaml (auto-detected if omitted) |
| `subdirectory` | string | Subdirectory hint for auto-detection |
| `substitutions` | string_dict | Template variable substitutions (`${VAR}` keys) |
| `images` | label_keyed_string_dict | Bazel image targets mapped to YAML image names |
| `external_images` | string_dict | External image references mapped to YAML image names |
| `manifest_registry` | string | Registry URL for k8s manifests |
| `repository_prefix` | string | Repository prefix for image paths |
| `load_restrictor` | string | `LoadRestrictionsNone` (default) or `LoadRestrictionsRootOnly` |

## Examples

See the [`examples/`](examples/) directory:

- [`examples/simple/`](examples/simple/) - Kustomize overlays with kubeconform validation

## License

Apache License 2.0
