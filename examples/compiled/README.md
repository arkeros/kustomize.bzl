# Compiled Example

Compiles kustomize from Go source using `rules_go` and registers it as a custom toolchain.
This provides fully hermetic builds — no pre-built binary download needed.

## Setup

Generate Go dependencies:

```bash
go mod tidy
```

## Usage

```bash
bazel build :prod_manifests
cat bazel-bin/prod_manifests.yaml
```

## How It Works

1. `go.mod` declares `sigs.k8s.io/kustomize/kustomize/v5` as a dependency
2. `gazelle` resolves Go deps into Bazel targets via `go_deps`
3. `kustomize_toolchain` wraps the compiled binary
4. `register_toolchains("//:kustomize_toolchain")` in MODULE.bazel makes it the default
5. `kustomize_binary` uses the compiled binary via the toolchain
