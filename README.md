# zUPX

[UPX](https://upx.github.io/) commandline tool build with zig to be used in other zig projects to compress executables in zig's build

## usage
fetch the dependency in your project
```bash
zig fetch --save https://github.com/SuSonicTH/zupx/archive/refs/tags/v0.1.0.tar.gz
```
add the dependency in you build.zig
```zig
const zupx = b.dependency("zupx", .{
    .optimize = std.builtin.OptimizeMode.ReleaseFast,
    .target = b.graph.host,
});
```
add a step to use upx
```zig
const upx_cmd = b.addRunArtifact(zupx.artifact("upx"));
const bin_path = b.getInstallPath(.bin, exe.out_filename);
upx_cmd.addArgs(&.{ "--lzma", bin_path });
upx_cmd.step.dependOn(b.getInstallStep());

const upx_step = b.step("upx", "compress the app with upx");
upx_step.dependOn(&upx_cmd.step);
```
now you can run `zig build upx` and it will automatically compile and run upx to compress your binary
