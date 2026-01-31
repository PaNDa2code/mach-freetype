const std = @import("std");

pub fn build(b: *std.Build) !void {
    const optimize = b.standardOptimizeOption(.{});
    const target = b.standardTargetOptions(.{});
    // const use_system_zlib = b.option(bool, "use_system_zlib", "Use system zlib") orelse false;
    // const enable_brotli = b.option(bool, "enable_brotli", "Build brotli") orelse true;

    const freetype_module = b.addModule("mach-freetype", .{
        .root_source_file = b.path("src/freetype.zig"),
    });
    const harfbuzz_module = b.addModule("mach-harfbuzz", .{
        .root_source_file = b.path("src/harfbuzz.zig"),
        .imports = &.{.{ .name = "freetype", .module = freetype_module }},
    });

    const freetype_lib = lib: {
        const freetype_upstream = b.dependency("freetype", .{});

        const mod = b.createModule(.{
            .target = target,
            .optimize = optimize,
            .link_libc = true,
        });

        mod.addCSourceFiles(.{
            .files = ft2_srcs,
            .flags = ft2_flags,
            .root = freetype_upstream.path("."),
        });

        const ftsys =
            switch (target.result.os.tag) {
                .windows => "builds/windows/ftsystem.c",
                else => "src/base/ftsystem.c",
            };

        mod.addCSourceFile(.{
            .file = freetype_upstream.path(ftsys),
            .flags = ft2_flags,
        });

        const ftdbg: []const []const u8 =
            switch (target.result.os.tag) {
                .windows => &.{"builds/windows/ftdebug.c"},
                else => &.{"src/base/ftdebug.c"},
            };

        mod.addCSourceFiles(.{
            .files = ftdbg,
            .flags = ft2_flags,
            .root = freetype_upstream.path("."),
        });

        mod.addIncludePath(freetype_upstream.path("include"));

        const lib = b.addLibrary(.{
            .name = "freetype",
            .root_module = mod,
            .linkage = .static,
        });

        lib.installHeadersDirectory(freetype_upstream.path("include/freetype"), "freetype", .{});
        lib.installHeader(freetype_upstream.path("include/ft2build.h"), "ft2build.h");
        break :lib lib;
    };

    const harfbuzz_lib = lib: {
        const hurfbuzz_upstream = b.dependency("harfbuzz", .{});

        const mod = b.createModule(.{
            .target = target,
            .optimize = optimize,
            .link_libcpp = true,
        });

        mod.addCSourceFile(.{
            .file = hurfbuzz_upstream.path("src/harfbuzz.cc"),
            .flags = &.{
                "-DHAVE_FREETYPE",
                "-DHB_NO_FEATURES_H",
                "-std=c++11",
                "-nostdlib++",
                "-fno-exceptions",
                "-fno-rtti",
                "-fno-threadsafe-statics",
                "-fvisibility-inlines-hidden",
            },
        });

        mod.addIncludePath(hurfbuzz_upstream.path("src"));
        mod.linkLibrary(freetype_lib);

        break :lib b.addLibrary(.{
            .name = "harfbuzz",
            .root_module = mod,
            .linkage = .static,
        });
    };

    freetype_module.linkLibrary(freetype_lib);
    harfbuzz_module.linkLibrary(harfbuzz_lib);

    // const freetype_tests = b.addTest(.{
    //     .name = "freetype-tests",
    //     .root_module = b.createModule(.{
    //         .root_source_file = b.path("src/freetype.zig"),
    //         .target = target,
    //         .optimize = optimize,
    //     }),
    // });
    // freetype_tests.root_module.addImport("freetype", freetype_module);
    //
    // const harfbuzz_tests = b.addTest(.{
    //     .name = "harfbuzz-tests",
    //     .root_module = b.createModule(.{
    //         .root_source_file = b.path("src/harfbuzz.zig"),
    //         .target = target,
    //         .optimize = optimize,
    //     }),
    // });
    //
    // harfbuzz_tests.root_module.addImport("freetype", freetype_module);
    // harfbuzz_tests.root_module.addImport("harfbuzz", harfbuzz_module);
    //
    // if (b.lazyDependency("freetype", .{
    //     .target = target,
    //     .optimize = optimize,
    //     .use_system_zlib = use_system_zlib,
    //     .enable_brotli = enable_brotli,
    // })) |dep| {
    //     freetype_tests.root_module.linkLibrary(dep.artifact("freetype"));
    //     freetype_module.linkLibrary(dep.artifact("freetype"));
    //     harfbuzz_module.linkLibrary(dep.artifact("freetype"));
    //     harfbuzz_tests.root_module.linkLibrary(dep.artifact("freetype"));
    // }
    // if (b.lazyDependency("harfbuzz", .{
    //     .target = target,
    //     .optimize = optimize,
    //     .enable_freetype = true,
    //     .freetype_use_system_zlib = use_system_zlib,
    //     .freetype_enable_brotli = enable_brotli,
    // })) |dep| {
    //     harfbuzz_module.linkLibrary(dep.artifact("harfbuzz"));
    //     harfbuzz_tests.root_module.linkLibrary(dep.artifact("harfbuzz"));
    // }
    //
    // const test_step = b.step("test", "Run library tests");
    // test_step.dependOn(&b.addRunArtifact(freetype_tests).step);
    // test_step.dependOn(&b.addRunArtifact(harfbuzz_tests).step);
    //
    // inline for ([_][]const u8{
    //     "single-glyph",
    //     "glyph-to-svg",
    // }) |example| {
    //     const example_exe = b.addExecutable(.{
    //         .name = example,
    //         .root_source_file = b.path("examples/" ++ example ++ ".zig"),
    //         .target = target,
    //         .optimize = optimize,
    //     });
    //     example_exe.root_module.addImport("freetype", freetype_module);
    //     if (b.lazyDependency("font_assets", .{})) |dep| {
    //         example_exe.root_module.addImport("font-assets", dep.module("font-assets"));
    //     }
    //
    //     const example_run_cmd = b.addRunArtifact(example_exe);
    //     if (b.args) |args| example_run_cmd.addArgs(args);
    //
    //     const example_run_step = b.step("run-" ++ example, "Run '" ++ example ++ "' example");
    //     example_run_step.dependOn(&example_run_cmd.step);
    // }
}

const ft2_srcs: []const []const u8 = &.{
    "src/autofit/autofit.c",
    "src/base/ftbase.c",
    "src/base/ftbbox.c",
    "src/base/ftbdf.c",
    "src/base/ftbitmap.c",
    "src/base/ftcid.c",
    "src/base/ftfstype.c",
    "src/base/ftgasp.c",
    "src/base/ftglyph.c",
    "src/base/ftgxval.c",
    "src/base/ftinit.c",
    "src/base/ftmm.c",
    "src/base/ftotval.c",
    "src/base/ftpatent.c",
    "src/base/ftpfr.c",
    "src/base/ftstroke.c",
    "src/base/ftsynth.c",
    "src/base/fttype1.c",
    "src/base/ftwinfnt.c",
    "src/bdf/bdf.c",
    "src/bzip2/ftbzip2.c",
    "src/cache/ftcache.c",
    "src/cff/cff.c",
    "src/cid/type1cid.c",
    "src/gzip/ftgzip.c",
    "src/lzw/ftlzw.c",
    "src/pcf/pcf.c",
    "src/pfr/pfr.c",
    "src/psaux/psaux.c",
    "src/pshinter/pshinter.c",
    "src/psnames/psnames.c",
    "src/raster/raster.c",
    "src/sdf/sdf.c",
    "src/sfnt/sfnt.c",
    "src/smooth/smooth.c",
    "src/svg/svg.c",
    "src/truetype/truetype.c",
    "src/type1/type1.c",
    "src/type42/type42.c",
    "src/winfonts/winfnt.c",
};

const ft2_flags: []const []const u8 = &.{
    "-DFT2_BUILD_LIBRARY",
    "-DHAVE_UNISTD_H",
    "-ffunction-sections",
    "-fdata-sections",
};
