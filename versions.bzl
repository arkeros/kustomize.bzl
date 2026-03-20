"""Kustomize version registry with SHA256 hashes."""

DEFAULT_KUSTOMIZE_VERSION = "5.6.0"

KUSTOMIZE_VERSIONS = {
    "5.6.0-darwin_amd64": ("kustomize_v5.6.0_darwin_amd64.tar.gz", "3432be97f9fb4899148bf2485ccf9080e5e7702758eb16c92cd2f2f335e12a03"),
    "5.6.0-darwin_arm64": ("kustomize_v5.6.0_darwin_arm64.tar.gz", "791d9497d2973d4af17c9c0c2b3991ce82e61d1a2bf79f4ef78dd9dce25a6d3d"),
    "5.6.0-linux_amd64": ("kustomize_v5.6.0_linux_amd64.tar.gz", "54e4031ddc4e7fc59e408da29e7c646e8e57b8088c51b84b3df0864f47b5148f"),
    "5.6.0-linux_arm64": ("kustomize_v5.6.0_linux_arm64.tar.gz", "ad8ab62d4f6d59a8afda0eec4ba2e5cd2f86bf1afeea4b78d06daac945eb0660"),
    "5.6.0-windows_amd64": ("kustomize_v5.6.0_windows_amd64.zip", "f21d94e9660b4f11a47c4fdc26b936d513f8aada879e5c53553abd27369ef3a1"),
}

def get_kustomize_url(version, filename):
    """Returns the download URL for a kustomize release."""
    return "https://github.com/kubernetes-sigs/kustomize/releases/download/kustomize/v{}/{}".format(version, filename)
