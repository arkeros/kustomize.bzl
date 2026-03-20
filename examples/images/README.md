# Image Substitution Example

Demonstrates the `kustomize` macro with mixed image sources:

- **External images** (`"redis": "redis:7.4-alpine"`) — passed through as-is
- **Bazel image targets** (`"app": ":app_image"`) — built, pushed, digest substituted

## Build

```bash
bazel build :k8s
cat bazel-bin/k8s.yaml
```

The rendered manifests will have:
- `redis` image set to `redis:7.4-alpine`
- `app` image set to `localhost:5000/example/app@sha256:<digest>`

## Push images

```bash
bazel run :k8s_push        # Push all Bazel images
bazel run :k8s_app_push    # Push only the app image
```

## How It Works

The `kustomize` macro splits the `images` dict:
1. String values that look like labels (`//`, `:`, `@`) → Bazel image targets
2. Plain strings → external image references

For Bazel targets, it:
1. Reads the digest from the image's `digest` output group
2. Runs `kustomize edit set image app=localhost:5000/example/app@sha256:<digest>`
3. Creates `image_push` targets for pushing to the registry
4. Creates a `multi_deploy` target (`:k8s_push`) that pushes all images
