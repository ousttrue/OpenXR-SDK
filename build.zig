const std = @import("std");
const android = @import("android");

pub fn build(b: *std.Build) void {
    const exe_name: []const u8 = "hello_xr";
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    if (target.result.abi.isAndroid()) {
        // zig build -Dtarget=x86_64-linux-android
        build_android(b, exe_name, target, optimize);
    } else {
        build_pc(b, exe_name, target, optimize);
    }
}

fn build_android(
    b: *std.Build,
    exe_name: []const u8,
    root_target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
) void {
    const android_targets = android.standardTargets(b, root_target);

    var root_target_single = [_]std.Build.ResolvedTarget{root_target};
    const targets: []std.Build.ResolvedTarget = if (android_targets.len == 0)
        root_target_single[0..]
    else
        android_targets;

    // If building with Android, initialize the tools / build
    const android_apk: ?*android.APK = blk: {
        if (android_targets.len == 0) {
            break :blk null;
        }
        const android_tools = android.Tools.create(b, .{
            .api_level = .android15,
            .build_tools_version = "35.0.1",
            .ndk_version = "29.0.13113456",
        });
        const apk = android.APK.create(b, android_tools);

        const key_store_file = android_tools.createKeyStore(android.CreateKey.example());
        apk.setKeyStore(key_store_file);
        apk.setAndroidManifest(b.path("android/AndroidManifest.xml"));
        apk.addResourceDirectory(b.path("android/res"));

        // Add Java files
        apk.addJavaSourceFile(.{ .file = b.path("android/src/NativeInvocationHandler.java") });
        break :blk apk;
    };

    for (targets) |target| {
        const app_module = b.createModule(.{
            .target = target,
            .optimize = optimize,
            .root_source_file = b.path("src/minimal.zig"),
        });

        var exe: *std.Build.Step.Compile = if (target.result.abi.isAndroid()) b.addLibrary(.{
            .name = exe_name,
            .root_module = app_module,
            .linkage = .dynamic,
        }) else b.addExecutable(.{
            .name = exe_name,
            .root_module = app_module,
        });

        // if building as library for Android, add this target
        // NOTE: Android has different CPU targets so you need to build a version of your
        //       code for x86, x86_64, arm, arm64 and more
        if (target.result.abi.isAndroid()) {
            const apk: *android.APK = android_apk orelse @panic("Android APK should be initialized");
            const android_dep = b.dependency("android", .{
                .optimize = optimize,
                .target = target,
            });
            exe.root_module.addImport("android", android_dep.module("android"));

            apk.addArtifact(exe);
        } else {
            b.installArtifact(exe);

            // If only 1 target, add "run" step
            if (targets.len == 1) {
                const run_step = b.step("run", "Run the application");
                const run_cmd = b.addRunArtifact(exe);
                run_step.dependOn(&run_cmd.step);
            }
        }
    }
    if (android_apk) |apk| {
        apk.installApk();
    }
}

fn build_pc(
    b: *std.Build,
    exe_name: []const u8,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
) void {
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
        .name = exe_name,
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
