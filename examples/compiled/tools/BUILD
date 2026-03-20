load("@gazelle//:go_tools.bzl", "GO_TOOLS")
load("@lazy_bazel_env.bzl//:defs.bzl", "lazy_bazel_env")

lazy_bazel_env(
    name = "dev",
    tools = {
        "go": "@rules_go//go",
    } | GO_TOOLS,
)
