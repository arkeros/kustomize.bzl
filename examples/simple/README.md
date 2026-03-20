# Kustomize + Kubeconform Example

Hermetic Kubernetes manifest builds with validation and deployment.

## Build

```bash
bazel build //:prod_manifests
```

## Validate

```bash
bazel test //:validate_prod_test
```

## Deploy

```bash
aspect deploy //:prod_manifests
```

## Image Substitution

The `kustomize` macro (see commented example in BUILD) supports mixed image sources:

- **External images** (e.g., `"redis": "redis:8.4.2"`) — passed through as-is via `kustomize edit set image`
- **Bazel image targets** (e.g., `"my-app/api": "//my-app/api:image_nonroot"`) — built, pushed to the registry, and their digest substituted into the manifests

Generated targets:
- `:k8s` — rendered manifests with image digests
- `:k8s_push` — pushes all Bazel images via `multi_deploy`
- `:k8s_<image>_push` — individual push target per image
