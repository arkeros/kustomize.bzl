"""Kustomize toolchain definition."""

KustomizeInfo = provider(
    doc = "Information about the kustomize binary.",
    fields = {
        "kustomize_binary": "The kustomize executable File.",
    },
)

def _kustomize_toolchain_impl(ctx):
    kustomize_files = ctx.attr.kustomize.files.to_list()
    if len(kustomize_files) == 0:
        fail("kustomize attribute must provide at least one file")

    kustomize_binary = kustomize_files[0]
    kustomize_info = KustomizeInfo(kustomize_binary = kustomize_binary)

    default_info = DefaultInfo(
        files = depset(kustomize_files),
        runfiles = ctx.runfiles(files = kustomize_files),
    )

    template_variables = platform_common.TemplateVariableInfo({
        "KUSTOMIZE_BIN": kustomize_binary.path,
    })

    toolchain_info = platform_common.ToolchainInfo(
        kustomize_info = kustomize_info,
        template_variables = template_variables,
        default = default_info,
    )

    return [default_info, toolchain_info, template_variables]

kustomize_toolchain = rule(
    implementation = _kustomize_toolchain_impl,
    attrs = {
        "kustomize": attr.label(
            mandatory = True,
            allow_files = True,
            executable = True,
            cfg = "exec",
        ),
    },
    provides = [DefaultInfo, platform_common.ToolchainInfo, platform_common.TemplateVariableInfo],
)
