# Copyright 2017 The Bazel Authors. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

"""embed_data.bzl provides the go_embed_data rule for embedding data in go files"""

load(
    "@io_bazel_rules_go//go/private:context.bzl",  #TODO: This ought to be def
    "go_context",
)
load(
    "@io_bazel_rules_go//go/private:rules/rule.bzl",
    "go_rule",
)

def _go_embed_data_impl(ctx):
    go = go_context(ctx)
    if ctx.attr.src and ctx.attr.srcs:
        fail("%s: src and srcs attributes cannot both be specified" % ctx.label)
    if ctx.attr.src and ctx.attr.flatten:
        fail("%s: src and flatten attributes cannot both be specified" % ctx.label)

    args = ctx.actions.args()
    if ctx.attr.src:
        srcs = [ctx.file.src]
    else:
        srcs = ctx.files.srcs
        args.add("-multi")

    if ctx.attr.package:
        package = ctx.attr.package
    else:
        _, _, package = ctx.label.package.rpartition("/")
        if package == "":
            fail("%s: must provide package attribute for go_embed_data rules in the repository root directory" % ctx.label)

    out = go.declare_file(go, ext = ".go")
    args.add_all([
        "-workspace",
        ctx.workspace_name,
        "-label",
        str(ctx.label),
        "-out",
        out,
        "-package",
        package,
        "-var",
        ctx.attr.var,
    ])
    if ctx.attr.flatten:
        args.add("-flatten")
    if ctx.attr.string:
        args.add("-string")
    if ctx.attr.unpack:
        args.add("-unpack")
        args.add("-multi")
    args.add_all(srcs)

    library = go.new_library(go, srcs = srcs)
    source = go.library_to_source(go, ctx.attr, library, ctx.coverage_instrumented())

    ctx.actions.run(
        outputs = [out],
        inputs = srcs,
        executable = ctx.executable._embed,
        arguments = [args],
        mnemonic = "GoSourcesData",
    )
    return [
        DefaultInfo(files = depset([out])),
        library,
        source,
    ]

go_embed_data = go_rule(
    implementation = _go_embed_data_impl,
    attrs = {
        "package": attr.string(),
        "var": attr.string(default = "Data"),
        "src": attr.label(allow_single_file = True),
        "srcs": attr.label_list(allow_files = True),
        "flatten": attr.bool(),
        "unpack": attr.bool(),
        "string": attr.bool(),
        "_embed": attr.label(
            default = "@io_bazel_rules_go//go/tools/builders:embed",
            executable = True,
            cfg = "host",
        ),
    },
)
# See go/extras.rst#go_embed_data for full documentation.
