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
