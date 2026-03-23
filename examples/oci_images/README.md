# rules_oci Image Substitution Example

Demonstrates the `kustomize` macro with `oci_images` for projects using
[rules_oci](https://github.com/bazel-contrib/rules_oci) instead of rules_img.

- **External images** (`"redis": "redis:7.4-alpine"`) — passed through as-is
- **rules_oci image targets** (`"app": ":app_image"`) — digest substituted automatically

## Build

```bash
bazel build :k8s
cat bazel-bin/k8s.yaml
```

The rendered manifests will have:
- `redis` image set to `redis:7.4-alpine`
- `app` image set to `localhost:5000/example/app@sha256:<digest>`

## How It Works

The `kustomize` macro accepts an `oci_images` dict alongside the existing `images` dict:

```starlark
kustomize(
    name = "k8s",
    srcs = glob(["k8s/**"]),
    images = {
        "redis": "redis:7.4-alpine",
    },
    oci_images = {
        "app": ":app_image",
    },
    manifest_registry = "localhost:5000",
    repository_prefix = "example",
)
```

For `oci_images` entries, the macro:
1. References the `.digest` sub-target that `oci_image` creates (e.g., `:app_image.digest`)
2. Reads the `sha256:...` digest from that file
3. Runs `kustomize edit set image app=localhost:5000/example/app@sha256:<digest>`

No push targets are created for `oci_images` — use rules_oci's `oci_push` separately.

## Comparison with rules_img

| | `images` (rules_img) | `oci_images` (rules_oci) |
|---|---|---|
| Digest source | `OutputGroupInfo.digest` provider | `.digest` sub-target file |
| Push | Auto-created `_push` targets | Use `oci_push` separately |
| Registry required | Yes (`registry` param) | No (only `manifest_registry`) |
