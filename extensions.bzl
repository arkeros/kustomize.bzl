"""Module extension for kustomize toolchain."""

load(":versions.bzl", "DEFAULT_KUSTOMIZE_VERSION", "KUSTOMIZE_VERSIONS", "get_kustomize_url")

def _detect_platform(ctx):
    """Detect the host platform for binary download."""
    os = ctx.os.name
    arch = ctx.os.arch

    if os == "mac os x" or os.startswith("darwin"):
        os_name = "darwin"
    elif os.startswith("linux"):
        os_name = "linux"
    elif os.startswith("windows"):
        os_name = "windows"
    else:
        fail("Unsupported OS: {}".format(os))

    if arch == "amd64" or arch == "x86_64":
        arch_name = "amd64"
    elif arch == "aarch64" or arch == "arm64":
        arch_name = "arm64"
    else:
        fail("Unsupported architecture: {}".format(arch))

    return "{}_{}".format(os_name, arch_name)

def _get_exec_constraints(platform):
    """Get exec constraints for a platform."""
    parts = platform.split("_")
    os_constraint = {"darwin": "@platforms//os:macos", "linux": "@platforms//os:linux", "windows": "@platforms//os:windows"}[parts[0]]
    arch_constraint = {"amd64": "@platforms//cpu:x86_64", "arm64": "@platforms//cpu:aarch64"}[parts[1]]
    return [os_constraint, arch_constraint]

def _kustomize_repo_impl(ctx):
    """Download kustomize binary and create toolchain."""
    platform = _detect_platform(ctx)
    version = ctx.attr.version
    key = "{}-{}".format(version, platform)

    if key not in KUSTOMIZE_VERSIONS:
        fail("Unsupported kustomize version/platform: {}".format(key))

    filename, sha256 = KUSTOMIZE_VERSIONS[key]
    url = get_kustomize_url(version, filename)

    ctx.download_and_extract(url = url, sha256 = sha256)

    binary_name = "kustomize.exe" if platform.startswith("windows") else "kustomize"

    ctx.file("BUILD.bazel", """
package(default_visibility = ["//visibility:public"])

load("@kustomize.bzl//toolchain:toolchain.bzl", "kustomize_toolchain")

exports_files(["{binary}"])

kustomize_toolchain(
    name = "toolchain",
    kustomize = ":{binary}",
)

toolchain(
    name = "kustomize_toolchain",
    exec_compatible_with = {constraints},
    toolchain = ":toolchain",
    toolchain_type = "@kustomize.bzl//:toolchain_type",
)
""".format(binary = binary_name, constraints = _get_exec_constraints(platform)))

kustomize_repo = repository_rule(
    implementation = _kustomize_repo_impl,
    attrs = {"version": attr.string(default = DEFAULT_KUSTOMIZE_VERSION)},
)

def _kustomize_extension_impl(ctx):
    for mod in ctx.modules:
        for toolchain in mod.tags.toolchain:
            kustomize_repo(
                name = "kustomize_toolchains",
                version = toolchain.version or DEFAULT_KUSTOMIZE_VERSION,
            )

kustomize = module_extension(
    implementation = _kustomize_extension_impl,
    tag_classes = {
        "toolchain": tag_class(attrs = {"version": attr.string()}),
    },
)
