load("@bazel_skylib//:bzl_library.bzl", "bzl_library")

# Prefer generated BUILD files to be called BUILD over BUILD.bazel
# gazelle:build_file_name BUILD,BUILD.bazel
# gazelle:prefix github.com/arkeros/kustomize.bzl
# gazelle:exclude bazel-kustomize.bzl

exports_files([
    "BUILD",
    "LICENSE",
    "MODULE.bazel",
])

toolchain_type(
    name = "toolchain_type",
    visibility = ["//visibility:public"],
)

bzl_library(
    name = "defs",
    srcs = ["defs.bzl"],
    visibility = ["//visibility:public"],
    deps = [
        "//toolchain",
        "@bazel_skylib//lib:paths",
    ],
)

bzl_library(
    name = "extensions",
    srcs = ["extensions.bzl"],
    visibility = ["//visibility:public"],
    deps = [":versions"],
)

bzl_library(
    name = "kustomize",
    srcs = ["kustomize.bzl"],
    visibility = ["//visibility:public"],
)

bzl_library(
    name = "versions",
    srcs = ["versions.bzl"],
    visibility = ["//visibility:public"],
)
