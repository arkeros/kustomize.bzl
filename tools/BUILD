load("@gazelle//:def.bzl", "DEFAULT_LANGUAGES", "gazelle", "gazelle_binary")
load("@gazelle//:go_tools.bzl", "GO_TOOLS")
load("@lazy_bazel_env.bzl//:defs.bzl", "lazy_bazel_env")

gazelle_binary(
    name = "gazelle_bin",
    languages = DEFAULT_LANGUAGES + [
        "@bazel_skylib_gazelle_plugin//bzl",
    ],
    visibility = [
        "//test:__pkg__",
    ],
)

gazelle(
    name = "gazelle",
    gazelle = ":gazelle_bin",
)

lazy_bazel_env(
    name = "dev",
    tools = {
        "gazelle": "//tools:gazelle",
        "go": "@rules_go//go",
        "prek": "@multitool//tools/prek",
    } | GO_TOOLS,
)
