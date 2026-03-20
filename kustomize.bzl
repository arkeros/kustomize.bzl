"""Public API for kustomize.bzl module."""

load("//:defs.bzl", _kustomize = "kustomize", _kustomize_binary = "kustomize_binary", _kustomize_library = "kustomize_library")
load("//toolchain:toolchain.bzl", _KustomizeInfo = "KustomizeInfo", _kustomize_toolchain = "kustomize_toolchain")

KustomizeInfo = _KustomizeInfo
kustomize_toolchain = _kustomize_toolchain
kustomize = _kustomize
kustomize_library = _kustomize_library
kustomize_binary = _kustomize_binary
