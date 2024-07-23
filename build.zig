const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});

    const tst = b.addTest(.{
        .name = "tst",
        .root_source_file = b.path("src/clock.zig"),
        .target = target,
    });

    b.installArtifact(tst);
}