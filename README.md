# zUPX

[UPX](https://upx.github.io/) command line tool built with Zig, for use in other Zig projects to compress executables as part of the build.

## Usage

Requires Zig 0.17.0 or newer. Use [v0.1.0](https://github.com/SuSonicTH/zupx/releases/tag/v0.1.0) for Zig 0.16.0.

Fetch the dependency in your project:

```bash
zig fetch --save https://github.com/SuSonicTH/zupx/archive/refs/tags/v0.2.0.tar.gz
```

Add the dependency in your `build.zig` (this builds UPX for the host so it can run during the build):

```zig
const zupx = b.dependency("zupx", .{
    .target = b.graph.host,
    .optimize = .ReleaseFast,
});
```

Add a step to compress your installed executable (assuming it is installed with `b.installArtifact(exe)`):

```zig
const upx_cmd = b.addRunArtifact(zupx.artifact("upx"));
upx_cmd.addArg("--lzma");
upx_cmd.addFileArg(b.graph.path(.install_bin, exe.out_filename));
upx_cmd.step.dependOn(b.getInstallStep());

const upx_step = b.step("upx", "Compress the app with UPX");
upx_step.dependOn(&upx_cmd.step);
```

Now run:

```bash
zig build upx
```

This builds and installs your executable, builds UPX, and compresses the installed binary in place.

Note that a later `zig build` (or `zig build install`) will reinstall the uncompressed executable, so run `zig build upx` again when you need a compressed artifact.
