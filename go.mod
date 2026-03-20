module github.com/arkeros/kustomize.bzl

go 1.25.4

tool (
	github.com/bazelbuild/buildtools/buildifier
	github.com/bazelbuild/buildtools/buildozer
)

require (
	github.com/bazelbuild/buildtools v0.0.0-20260121081817-bbf01ec6cb49 // indirect
	github.com/golang/protobuf v1.5.0 // indirect
	google.golang.org/protobuf v1.33.0 // indirect
)
