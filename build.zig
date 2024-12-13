const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const lib = b.addStaticLibrary(.{
        .name = "OpenXR-SDK",
        .target = target,
        .optimize = optimize,
    });
    b.installArtifact(lib);
    lib.addCSourceFiles(.{
        .files = &.{
            "src/loader/loader_core.cpp",
            "src/loader/loader_instance.cpp",
            "src/loader/loader_logger.cpp",
            "src/loader/loader_logger_recorders.cpp",
            "src/loader/api_layer_interface.cpp",
            "src/loader/runtime_interface.cpp",
            "src/loader/xr_generated_loader.cpp",
            "src/loader/manifest_file.cpp",
            "src/common/object_info.cpp",
            "src/common/filesystem_utils.cpp",
            "src/xr_generated_dispatch_table.c",
            "src/xr_generated_dispatch_table_core.c",
            "src/external/jsoncpp/example/readFromStream/readFromStream.cpp",
            "src/external/jsoncpp/example/readFromString/readFromString.cpp",
            "src/external/jsoncpp/example/streamWrite/streamWrite.cpp",
            "src/external/jsoncpp/example/stringWrite/stringWrite.cpp",
            "src/external/jsoncpp/src/jsontestrunner/main.cpp",
            "src/external/jsoncpp/src/lib_json/json_reader.cpp",
            "src/external/jsoncpp/src/lib_json/json_value.cpp",
            "src/external/jsoncpp/src/lib_json/json_writer.cpp",
            "src/external/jsoncpp/src/test_lib_json/fuzz.cpp",
            "src/external/jsoncpp/src/test_lib_json/jsontest.cpp",
            "src/external/jsoncpp/src/test_lib_json/main.cpp",
        },
        .flags = &.{
            "-DXR_OS_WINDOWS",
            "-DXR_USE_PLATFORM_WIN32",
            "-DXR_USE_GRAPHICS_API_OPENGL",
        },
    });
    lib.linkLibCpp();
    lib.addIncludePath(b.path("include"));
    lib.addIncludePath(b.path("src/common"));
    lib.addIncludePath(b.path("src"));
    lib.addIncludePath(b.path("src/external/jsoncpp/include"));

    const openxr_src_dep = b.dependency("openxr-source", .{});
    const exe = b.addExecutable(.{
        .name = "hello_xr",
        .target = target,
        .optimize = optimize,
    });
    exe.addCSourceFiles(.{
        .root = openxr_src_dep.path("src"),
        .files = &.{
            "tests/hello_xr/main.cpp",
            "tests/hello_xr/platformplugin_factory.cpp",
            "tests/hello_xr/platformplugin_win32.cpp",
            "tests/hello_xr/graphicsplugin_factory.cpp",
            "tests/hello_xr/graphicsplugin_opengl.cpp",
            "tests/hello_xr/openxr_program.cpp",
            "tests/hello_xr/logger.cpp",
            "common/gfxwrapper_opengl.c",
        },
        .flags = &.{
            "-DXR_USE_PLATFORM_WIN32",
            "-DXR_USE_GRAPHICS_API_OPENGL",
        },
    });
    b.installArtifact(exe);
    exe.linkLibCpp();
    exe.linkLibrary(lib);
    exe.addIncludePath(b.path("include"));
    exe.addIncludePath(openxr_src_dep.path("src"));
    exe.addIncludePath(openxr_src_dep.path("external/include"));
    exe.linkSystemLibrary("ole32");
    exe.linkSystemLibrary("opengl32");
    exe.linkSystemLibrary("gdi32");
}
