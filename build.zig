const std = @import("std");

pub fn build(b: *std.Build) !void {
    const optimize = b.standardOptimizeOption(.{});
    const target = b.standardTargetOptions(.{});

    const use_llvm = b.option(bool, "use_llvm", "") orelse false;
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
            .use_llvm = use_llvm,
        });

        // if (use_system_zlib)
        //     mod.addCMacro("FT_CONFIG_OPTION_SYSTEM_ZLIB", "");
        //
        // if (enable_brotli) {
        //     mod.addCMacro("FT_CONFIG_OPTION_USE_BROTLI", "1");
        //     if (b.lazyDependency("brotli", .{
        //         .target = target,
        //         .optimize = optimize,
        //     })) |dep| lib.linkLibrary(dep.artifact("brotli"));
        // }

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
            .flags = hb_flags,
        });

        mod.addCMacro("HAVE_FREETYPE", "");
        mod.addCMacro("HB_NO_FEATURES_H", "");

        mod.addIncludePath(hurfbuzz_upstream.path("src"));

        mod.linkLibrary(freetype_lib);
        mod.addIncludePath(freetype_lib.getEmittedIncludeTree());

        const lib = b.addLibrary(.{
            .name = "harfbuzz",
            .root_module = mod,
            .linkage = .static,
            .use_llvm = use_llvm,
        });

        lib.installHeadersDirectory(hurfbuzz_upstream.path("src/"), "harfbuzz", .{});

        break :lib lib;
    };

    freetype_module.linkLibrary(freetype_lib);
    harfbuzz_module.linkLibrary(harfbuzz_lib);

    freetype_module.addIncludePath(freetype_lib.getEmittedIncludeTree());
    harfbuzz_module.addIncludePath(harfbuzz_lib.getEmittedIncludeTree());

    harfbuzz_module.addIncludePath(freetype_lib.getEmittedIncludeTree());
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

const hb_flags: []const []const u8 = &.{
    "-std=c++11",
    "-nostdlib++",
    "-fno-exceptions",
    "-fno-rtti",
    "-fno-threadsafe-statics",
    "-fvisibility-inlines-hidden",
};
