const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const upx_dep = b.dependency("upx", .{});
    const ucl_dep = b.dependency("ucl", .{});
    const zlib_dep = b.dependency("zlib", .{});
    const lzma_sdk_dep = b.dependency("lzma_sdk", .{});
    const doctest_dep = b.dependency("doctest", .{});
    const valgrind_dep = b.dependency("valgrind", .{});

    const include_wf = b.addWriteFiles();
    _ = include_wf.addCopyDirectory(ucl_dep.path(""), "ucl", .{});
    _ = include_wf.addCopyDirectory(zlib_dep.path(""), "zlib", .{});
    _ = include_wf.addCopyDirectory(lzma_sdk_dep.path(""), "lzma-sdk", .{});
    _ = include_wf.addCopyDirectory(doctest_dep.path(""), "doctest", .{});
    _ = include_wf.addCopyDirectory(valgrind_dep.path(""), "valgrind", .{});
    const extra_include = include_wf.getDirectory();

    const ucl_lib = b.addLibrary(.{
        .name = "ucl",
        .root_module = b.createModule(.{
            .target = target,
            .optimize = optimize,
            .link_libc = true,
        }),
    });
    ucl_lib.root_module.addIncludePath(ucl_dep.path("include"));
    ucl_lib.root_module.addIncludePath(ucl_dep.path(""));

    const zlib_lib = b.addLibrary(.{
        .name = "zlib",
        .root_module = b.createModule(.{
            .target = target,
            .optimize = optimize,
            .link_libc = true,
        }),
    });
    zlib_lib.root_module.addIncludePath(zlib_dep.path(""));
    zlib_lib.root_module.addCMacro("HAVE_VSNPRINTF", "1");

    const target_os = target.result.os.tag;
    if (target_os != .windows) {
        zlib_lib.root_module.addCMacro("HAVE_UNISTD_H", "1");
    }

    const upx_exe = b.addExecutable(.{
        .name = "upx",
        .root_module = b.createModule(.{
            .target = target,
            .optimize = optimize,
            .link_libc = true,
            .link_libcpp = true,
        }),
    });

    upx_exe.root_module.addIncludePath(upx_dep.path("src"));
    upx_exe.root_module.addIncludePath(ucl_dep.path("include"));
    upx_exe.root_module.addIncludePath(extra_include);

    if (target_os == .linux or target_os == .macos) {
        upx_exe.root_module.addCMacro("USE_UTIMENSAT", "1");
    }
    if (target_os == .windows) {
        upx_exe.root_module.addCMacro("WIN32_LEAN_AND_MEAN", "1");
    }

    const c_flags = &.{ "-std=c99", "-fno-delete-null-pointer-checks", "-fno-strict-aliasing", "-fno-strict-overflow", "-funsigned-char", "-fno-tree-vectorize" };
    const cpp_flags = &.{ "-std=c++17", "-fno-delete-null-pointer-checks", "-fno-strict-aliasing", "-fno-strict-overflow", "-funsigned-char", "-fno-tree-vectorize" };

    addSourcesFromDependency(b, ucl_lib, "ucl", "src", c_flags) catch |err| {
        std.debug.panic("failed to add UCL source files: {any}", .{err});
    };

    addSourcesFromDependency(b, zlib_lib, "zlib", "", c_flags) catch |err| {
        std.debug.panic("failed to add Zlib source files: {any}", .{err});
    };

    addSourcesFromDependency(b, upx_exe, "upx", "src", cpp_flags) catch |err| {
        std.debug.panic("failed to add UPX source files: {any}", .{err});
    };
    addSourcesFromDependency(b, upx_exe, "upx", "src/compress", cpp_flags) catch |err| {
        std.debug.panic("failed to add UPX compress source files: {any}", .{err});
    };
    addSourcesFromDependency(b, upx_exe, "upx", "src/check", cpp_flags) catch |err| {
        std.debug.panic("failed to add UPX check source files: {any}", .{err});
    };
    addSourcesFromDependency(b, upx_exe, "upx", "src/console", cpp_flags) catch |err| {
        std.debug.panic("failed to add UPX console source files: {any}", .{err});
    };
    addSourcesFromDependency(b, upx_exe, "upx", "src/filter", cpp_flags) catch |err| {
        std.debug.panic("failed to add UPX filter source files: {any}", .{err});
    };
    addSourcesFromDependency(b, upx_exe, "upx", "src/util", cpp_flags) catch |err| {
        std.debug.panic("failed to add UPX util source files: {any}", .{err});
    };

    upx_exe.root_module.linkLibrary(ucl_lib);
    upx_exe.root_module.linkLibrary(zlib_lib);

    b.installArtifact(upx_exe);
}

fn addSourcesFromDependency(
    b: *std.Build,
    exe: *std.Build.Step.Compile,
    dep_name: []const u8,
    sub_dir: []const u8,
    flags: []const []const u8,
) !void {
    const dep = b.dependency(dep_name, .{});

    // The configure phase may inspect dependency directories, but doing so must
    // be declared so that `zig build` knows when to rerun the build script.
    b.dependOnDirectoryContents(dep.path(sub_dir));

    var dir = try dep.builder.root.openDir(b.graph.io, if (sub_dir.len > 0) sub_dir else ".", .{ .iterate = true });
    defer dir.close(b.graph.io);

    var it = dir.iterate();
    while (try it.next(b.graph.io)) |entry| {
        const ext = std.fs.path.extension(entry.name);
        if (std.mem.eql(u8, ext, ".cpp") or std.mem.eql(u8, ext, ".c")) {
            if (std.mem.eql(u8, entry.name, "example.c") or std.mem.eql(u8, entry.name, "minigzip.c")) {
                continue;
            }

            const relative_file_path = if (sub_dir.len > 0)
                try std.fs.path.join(b.allocator, &.{ sub_dir, entry.name })
            else
                entry.name;
            exe.root_module.addCSourceFile(.{
                .file = dep.path(relative_file_path),
                .flags = flags,
            });
        }
    }
}
