"""Kustomize rules for building Kubernetes manifests."""

load("@rules_img//img:multi_deploy.bzl", "multi_deploy")
load("@rules_img//img:push.bzl", "image_push")
load("//toolchain:toolchain.bzl", "KustomizeInfo")

KustomizationInfo = provider(
    doc = "Information about a kustomization.",
    fields = {
        "kustomization_dir": "Path to the directory containing kustomization.yaml.",
        "files": "Depset of all files in the kustomization.",
    },
)

def _find_kustomization_dir(files, subdirectory = None):
    """Find the directory containing kustomization.yaml.

    Args:
        files: List of files to search.
        subdirectory: Optional subdirectory to match.

    Returns:
        The directory path containing kustomization.yaml, or None.
    """
    for f in files:
        if f.basename in ["kustomization.yaml", "kustomization.yml", "Kustomization"]:
            if subdirectory:
                if f.dirname.endswith("/" + subdirectory) or f.dirname == subdirectory:
                    return f.dirname
            else:
                return f.dirname
    return None

def _join_path(*segments):
    """Join path segments, filtering out empty strings.

    Args:
        *segments: Path segments to join.

    Returns:
        Joined path string.
    """
    return "/".join([s for s in segments if s])

def _sanitize_name(value):
    return value.replace("/", "_").replace(":", "_").replace(".", "_")

def _kustomize_library_impl(ctx):
    all_files = depset(ctx.files.srcs + ctx.files.deps)
    kustomization_dir = _find_kustomization_dir(ctx.files.srcs)
    if not kustomization_dir:
        fail("No kustomization.yaml found in srcs")

    return [
        DefaultInfo(files = all_files),
        KustomizationInfo(kustomization_dir = kustomization_dir, files = all_files),
    ]

kustomize_library = rule(
    implementation = _kustomize_library_impl,
    attrs = {
        "srcs": attr.label_list(allow_files = True, mandatory = True),
        "deps": attr.label_list(allow_files = True),
    },
    provides = [DefaultInfo, KustomizationInfo],
)

def _get_digest_files(image_target):
    """Extract digest files from an image target.

    Supports both rules_img (OutputGroupInfo.digest) and rules_oci (.digest targets
    that produce plain files via DefaultInfo).

    Args:
        image_target: A Bazel target providing image digest information.

    Returns:
        List of digest files.
    """
    if OutputGroupInfo in image_target and hasattr(image_target[OutputGroupInfo], "digest"):
        digest_files = image_target[OutputGroupInfo].digest.to_list()
        if digest_files:
            return digest_files

    # Fallback: use DefaultInfo files (for rules_oci .digest targets).
    digest_files = image_target[DefaultInfo].files.to_list()
    if digest_files:
        return digest_files

    fail("Image target %s produced no digest files" % image_target.label)

def _kustomize_binary_impl(ctx):
    if ctx.attr.kustomize:
        kustomize_binary = ctx.executable.kustomize
    else:
        toolchain = ctx.toolchains["@kustomize.bzl//:toolchain_type"]
        if not toolchain:
            fail("No kustomize toolchain found.")
        kustomize_binary = toolchain.kustomize_info.kustomize_binary

    input_files = []
    for src in ctx.attr.srcs:
        input_files.extend(src.files.to_list())
    for dep in ctx.attr.deps:
        input_files.extend(dep.files.to_list())

    if ctx.attr.kustomization_dir:
        kustomization_dir = ctx.attr.kustomization_dir
    else:
        kustomization_dir = _find_kustomization_dir(input_files, ctx.attr.subdirectory)
        if not kustomization_dir:
            msg = "No kustomization.yaml found"
            if ctx.attr.subdirectory:
                msg += " matching subdirectory '{}'".format(ctx.attr.subdirectory)
            msg += ". Specify kustomization_dir attribute."
            fail(msg)

    final_output = ctx.actions.declare_file(ctx.label.name + ".yaml")
    if ctx.attr.substitutions:
        kustomize_output = ctx.actions.declare_file(ctx.label.name + "_pre_env.yaml")
    else:
        kustomize_output = final_output

    output = kustomize_output
    args = ctx.actions.args()
    args.add("build")
    args.add("--load-restrictor", ctx.attr.load_restrictor)
    args.add("--output", output)

    # Check if any input files are generated (path != short_path) or from
    # external repos (short_path starts with "../"). These files won't be at
    # the workspace-relative paths that kustomization.yaml expects in the
    # sandbox, so we need to copy them to a working directory.
    needs_copy = False
    for f in input_files:
        if f.path != f.short_path or f.short_path.startswith("../"):
            needs_copy = True
            break

    has_images = bool(ctx.attr.images)
    has_external_images = bool(ctx.attr.external_images)
    if has_images or has_external_images or needs_copy:
        # Use script to copy files to a working directory so that kustomize
        # sees them at their workspace-relative paths.
        image_inputs = []
        for image_target, yaml_name in ctx.attr.images.items():
            image_inputs.extend(_get_digest_files(image_target))

        copy_commands = []
        for f in input_files:
            rel_path = f.short_path
            if rel_path.startswith("../"):
                # External repo: short_path is "../<canonical_repo_name>/file.yaml"
                # Prefix with "external/" to match kustomize relative path expectations.
                rel_path = "external/" + rel_path[3:]
            copy_commands.append('REL_PATH="{}"; REL_PATH=$(echo "$REL_PATH" | sed "s|external/+[^+]*+|external/|"); mkdir -p "$WORKDIR/$(dirname "$REL_PATH")" && cp "$EXECROOT/{}" "$WORKDIR/$REL_PATH"'.format(rel_path, f.path))

        image_commands = []
        for yaml_name, image_ref in ctx.attr.external_images.items():
            image_commands.append(
                'cd "$KUSTOMIZATION_DIR" && "$KUSTOMIZE" edit set image "{}={}"; cd "$WORKDIR"'.format(
                    yaml_name,
                    image_ref,
                ),
            )

        for image_target, yaml_name in ctx.attr.images.items():
            if not ctx.attr.manifest_registry:
                fail("manifest_registry is required when images are specified")
            digest_file = _get_digest_files(image_target)[0]
            repo_url = _join_path(ctx.attr.manifest_registry, ctx.attr.repository_prefix, yaml_name)
            image_commands.append(
                'DIGEST=$(cat "$EXECROOT/{}"); cd "$KUSTOMIZATION_DIR" && "$KUSTOMIZE" edit set image "{}={}@${{DIGEST}}"; cd "$WORKDIR"'.format(
                    digest_file.path,
                    yaml_name,
                    repo_url,
                ),
            )

        # Normalize kustomization_dir the same way copy commands normalize paths:
        # strip Bazel's internal +<segment>+ prefix from external repo paths
        # e.g., external/+_repo_rules3+redis-operator -> external/redis-operator
        normalized_kustomization_dir = kustomization_dir
        if normalized_kustomization_dir.startswith("external/+"):
            # Find the second '+' and strip from first '+' to second '+' inclusive
            rest = normalized_kustomization_dir[len("external/+"):]
            plus_idx = rest.find("+")
            if plus_idx >= 0:
                normalized_kustomization_dir = "external/" + rest[plus_idx + 1:]

        script = ctx.actions.declare_file(ctx.label.name + "_kustomize.sh")
        ctx.actions.write(
            output = script,
            content = """#!/bin/bash
set -euo pipefail
EXECROOT="$PWD"
KUSTOMIZE="$EXECROOT/{kustomize}"
OUTPUT="$EXECROOT/{output}"
LOAD_RESTRICTOR="{load_restrictor}"
WORKDIR=$(mktemp -d)
KUSTOMIZATION_DIR="$WORKDIR/{kustomization_dir}"
trap "rm -rf $WORKDIR" EXIT
{copy_commands}
cd "$WORKDIR"
{image_commands}
"$KUSTOMIZE" build --load-restrictor="$LOAD_RESTRICTOR" "$KUSTOMIZATION_DIR" > "$OUTPUT"
""".format(
                kustomize = kustomize_binary.path,
                kustomization_dir = normalized_kustomization_dir,
                output = output.path,
                load_restrictor = ctx.attr.load_restrictor,
                copy_commands = "\n".join(copy_commands),
                image_commands = "\n".join(image_commands),
            ),
            is_executable = True,
        )

        ctx.actions.run(
            outputs = [output],
            inputs = input_files + image_inputs + [kustomize_binary],
            executable = script,
            mnemonic = "KustomizeBuild",
            progress_message = "Building kustomization %{label}",
            use_default_shell_env = True,
        )
    else:
        args.add(kustomization_dir)
        ctx.actions.run(
            outputs = [output],
            inputs = input_files + [kustomize_binary],
            executable = kustomize_binary,
            arguments = [args],
            mnemonic = "KustomizeBuild",
            progress_message = "Building kustomization %{label}",
        )

    if ctx.attr.substitutions:
        # Write each substitution key and value to separate files to avoid
        # shell escaping issues. The substitution script reads these files
        # and replaces keys in the template, indenting multiline values to
        # match the indentation at the substitution point.
        subst_inputs = [kustomize_output]
        key_value_args = []
        for i, (key, value) in enumerate(ctx.attr.substitutions.items()):
            key_file = ctx.actions.declare_file("{}_subst_key_{}".format(ctx.label.name, i))
            val_file = ctx.actions.declare_file("{}_subst_val_{}".format(ctx.label.name, i))
            ctx.actions.write(output = key_file, content = key)
            ctx.actions.write(output = val_file, content = value)
            subst_inputs.extend([key_file, val_file])
            key_value_args.extend([key_file.path, val_file.path])

        subst_script = ctx.actions.declare_file(ctx.label.name + "_subst.sh")
        ctx.actions.write(
            output = subst_script,
            content = """#!/bin/bash
set -euo pipefail
INPUT="$1"; shift
OUTPUT="$1"; shift
cp "$INPUT" "$OUTPUT.tmp"
while [ $# -ge 2 ]; do
    KEY_FILE="$1"; shift
    VAL_FILE="$1"; shift
    KEY=$(cat "$KEY_FILE")
    # Use awk to replace KEY with the contents of VAL_FILE,
    # indenting continuation lines to match the substitution point.
    awk -v key="$KEY" -v valfile="$VAL_FILE" '
    BEGIN {
        val = ""
        while ((getline line < valfile) > 0) {
            if (val != "") val = val "\\n"
            val = val line
        }
        close(valfile)
    }
    {
        idx = index($0, key)
        if (idx > 0) {
            prefix = substr($0, 1, idx - 1)
            suffix = substr($0, idx + length(key))
            match($0, /^[ \\t]*/)
            indent = substr($0, RSTART, RLENGTH)
            n = split(val, parts, "\\n")
            result = prefix parts[1]
            for (i = 2; i <= n; i++) {
                result = result "\\n" indent parts[i]
            }
            print result suffix
        } else {
            print
        }
    }' "$OUTPUT.tmp" > "$OUTPUT.tmp2"
    mv "$OUTPUT.tmp2" "$OUTPUT.tmp"
done
mv "$OUTPUT.tmp" "$OUTPUT"
""",
            is_executable = True,
        )

        ctx.actions.run(
            outputs = [final_output],
            inputs = subst_inputs,
            executable = subst_script,
            arguments = [kustomize_output.path, final_output.path] + key_value_args,
            mnemonic = "KustomizeSubstitute",
            progress_message = "Substituting variables in %{label}",
        )

    return [DefaultInfo(files = depset([final_output]))]

kustomize_binary = rule(
    implementation = _kustomize_binary_impl,
    attrs = {
        "srcs": attr.label_list(allow_files = True, mandatory = True),
        "deps": attr.label_list(allow_files = True),
        "kustomization_dir": attr.string(
            doc = "The directory containing kustomization.yaml (overrides auto-detection)",
        ),
        "subdirectory": attr.string(
            doc = "Relative subdirectory containing kustomization.yaml (for repos with multiple kustomizations)",
        ),
        "substitutions": attr.string_dict(
            doc = "Substitutions applied to kustomize output. Keys use ${VAR} syntax. E.g. {'${HOSTNAME}': 'example.com'}.",
        ),
        "images": attr.label_keyed_string_dict(allow_files = True),
        "external_images": attr.string_dict(
            doc = "Map of image names (as they appear in YAML) to external image references.",
        ),
        "manifest_registry": attr.string(
            doc = "Registry URL to use in k8s manifests (e.g., 'registry.local').",
        ),
        "repository_prefix": attr.string(
            doc = "Repository prefix (e.g., 'myproject/repo').",
        ),
        "load_restrictor": attr.string(default = "LoadRestrictionsNone", values = ["LoadRestrictionsRootOnly", "LoadRestrictionsNone"]),
        "kustomize": attr.label(executable = True, cfg = "exec"),
    },
    toolchains = [config_common.toolchain_type("@kustomize.bzl//:toolchain_type", mandatory = False)],
)

def kustomize(
        name,
        images = {},
        oci_images = {},
        substitutions = {},
        registry = None,
        manifest_registry = None,
        repository_prefix = None,
        visibility = None,
        **kwargs):
    """Kustomize build with user-friendly image API.

    This macro wraps kustomize_binary and creates the necessary repository/digest
    file references for image substitution in manifests.

    Args:
        name: The name of the target.
        images: Map of image names (as they appear in YAML) to either Bazel image
                targets (labels) or external image references (strings).
                Example: {"my_app": "//app:image", "redis": "redis:6.2.19-alpine"}
                Bazel image targets must expose a "digest" output group (rules_img).
        oci_images: Map of image names (as they appear in YAML) to rules_oci image
                    targets (labels). The macro automatically references the .digest
                    sub-target. Push is handled separately by rules_oci's oci_push.
                    Example: {"reporting": "//batch:image"}
        registry: Container registry for pushing images (e.g., "localhost:49291").
                  Required if rules_img Bazel image targets are specified in images.
        manifest_registry: Registry URL to use in k8s manifests (e.g., "registry.local").
                           Defaults to registry if not specified. Useful when the cluster
                           sees the registry at a different address than the build host.
        repository_prefix: Repository prefix (e.g., "myproject/repo").
        visibility: The visibility of the generated targets.
        **kwargs: Additional arguments passed to kustomize_binary.
    """

    # Split image entries into Bazel targets vs external image references.
    images_attr = {}
    external_images = {}
    for yaml_name, image_value in images.items():
        if type(image_value) == "string" and (
            image_value.startswith("//") or
            image_value.startswith(":") or
            image_value.startswith("@")
        ):
            images_attr[image_value] = yaml_name
        elif type(image_value) == "string":
            external_images[yaml_name] = image_value
        else:
            fail("Unsupported image value for %s: %s" % (yaml_name, image_value))

    # rules_oci images: reference the .digest sub-target for digest extraction.
    # Track these separately so we don't create rules_img push targets for them.
    oci_digest_labels = {}
    for yaml_name, image_label in oci_images.items():
        digest_label = image_label + ".digest"
        images_attr[digest_label] = yaml_name
        oci_digest_labels[digest_label] = True

    if images_attr and not registry and not oci_images:
        fail("registry is required when Bazel image targets are specified")

    # Use manifest_registry for k8s manifests, falling back to registry
    manifest_registry = manifest_registry or registry

    kustomize_binary(
        name = name,
        substitutions = substitutions,
        images = images_attr if images_attr else {},
        external_images = external_images if external_images else {},
        manifest_registry = manifest_registry,
        repository_prefix = repository_prefix,
        visibility = visibility,
        **kwargs
    )

    # Create push targets only for rules_img images (not rules_oci).
    push_targets = []
    for image_label, yaml_name in images_attr.items():
        if image_label in oci_digest_labels:
            continue
        if not registry:
            fail("registry is required when rules_img image targets are specified")
        push_name = "{}_{}_push".format(name, _sanitize_name(yaml_name))
        image_push(
            name = push_name,
            image = image_label,
            registry = registry,
            repository = _join_path(repository_prefix, yaml_name),
            tag_file = "//:image_tags",
            visibility = visibility,
        )
        push_targets.append(":" + push_name)

    if push_targets:
        multi_deploy(
            name = name + "_push",
            operations = push_targets,
            visibility = visibility,
        )
