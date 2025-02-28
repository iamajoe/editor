const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // executable
    const exe = b.addExecutable(.{
        .name = "editor",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    // dependencies
    const vaxis = b.dependency("vaxis", .{ .target = target, .optimize = optimize });
    exe.root_module.addImport("vaxis", vaxis.module("vaxis"));

    const tree_sitter = b.dependency("tree-sitter", .{ .target = target, .optimize = optimize });
    exe.root_module.addImport("tree-sitter", tree_sitter.module("tree-sitter"));

    // dependencies: treesitter javascript grammar
    const ts_javascript = b.dependency("tree_sitter_javascript", .{});
    exe.addCSourceFile(.{ .file = ts_javascript.path("src/parser.c") });
    exe.addCSourceFile(.{ .file = ts_javascript.path("src/scanner.c") });

    // dependencies: treesitter zig grammar
    const ts_zig = b.dependency("tree_sitter_zig", .{});
    exe.addCSourceFile(.{ .file = ts_zig.path("src/parser.c") });
    // exe.linkLibrary(tree_sitter_zig.artifact("tree-sitter-zig"));

    // dependencies: treesitter markdown grammar
    const ts_md = b.dependency("tree_sitter_markdown", .{});
    exe.addCSourceFile(.{ .file = ts_md.path("tree-sitter-markdown/src/parser.c") });
    exe.addCSourceFile(.{ .file = ts_md.path("tree-sitter-markdown/src/scanner.c") });

    // dependencies: treesitter yaml grammar
    const ts_yaml = b.dependency("tree_sitter_yaml", .{});
    exe.addCSourceFile(.{ .file = ts_yaml.path("src/parser.c") });
    exe.addCSourceFile(.{ .file = ts_yaml.path("src/scanner.c") });

    // dependencies: treesitter make grammar
    const ts_make = b.dependency("tree_sitter_make", .{});
    exe.addCSourceFile(.{ .file = ts_make.path("src/parser.c") });

    // dependencies: treesitter toml grammar
    const ts_toml = b.dependency("tree_sitter_toml", .{});
    exe.addCSourceFile(.{ .file = ts_toml.path("src/parser.c") });
    exe.addCSourceFile(.{ .file = ts_toml.path("src/scanner.c") });

    // dependencies: treesitter csv grammar
    const ts_csv = b.dependency("tree_sitter_csv", .{});
    // TODO: they also have psv and tsv
    exe.addCSourceFile(.{ .file = ts_csv.path("csv/src/parser.c") });

    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    const exe_unit_tests = b.addTest(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    const run_exe_unit_tests = b.addRunArtifact(exe_unit_tests);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_exe_unit_tests.step);

    // run tests under lldb for possible debugger
    const lldb = b.addSystemCommand(&.{
        "lldb",
        // add lldb flags before --
        "--",
    });
    lldb.addArtifactArg(exe_unit_tests);
    const lldb_step = b.step("debug", "run the tests under lldb");
    lldb_step.dependOn(&lldb.step);
}
