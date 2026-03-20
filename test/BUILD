load("@gazelle//:def.bzl", "gazelle_test")

package(default_visibility = ["//visibility:public"])

gazelle_test(
    name = "gazelle.check",
    size = "small",
    gazelle = "//tools:gazelle_bin",
    workspace = "//:BUILD",
)
