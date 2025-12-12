const std = @import("std");

// Dedicated build file for Zisk zkVM (RISC-V RV64IM) target
// This build file is specifically for building zevm for the Zisk zero-knowledge virtual machine
//
// Usage:
//   zig build -Dbuild-file=build.zisk.zig
//
// This will automatically target riscv64-freestanding and disable crypto libraries
// that are not available in the freestanding environment.

pub fn build(b: *std.Build) void {
    // Force RISC-V 64-bit freestanding target for Zisk zkVM
    const target = b.resolveTargetQuery(.{
        .cpu_arch = .riscv64,
        .os_tag = .freestanding,
        .abi = .none,
    });

    // Optimize for size or speed as needed
    const optimize = b.standardOptimizeOption(.{});

    // Build options - crypto libraries are disabled for freestanding
    const lib_options = b.addOptions();
    lib_options.addOption(bool, "enable_blst", false);
    lib_options.addOption(bool, "enable_mcl", false);
    const lib_options_module = lib_options.createModule();

    // Create modules for each component
    const primitives_module = b.addModule("primitives", .{
        .root_source_file = .{ .src_path = .{ .owner = b, .sub_path = "src/primitives/main.zig" } },
        .target = target,
        .optimize = optimize,
    });

    const bytecode_module = b.addModule("bytecode", .{
        .root_source_file = .{ .src_path = .{ .owner = b, .sub_path = "src/bytecode/main.zig" } },
        .target = target,
        .optimize = optimize,
    });

    const state_module = b.addModule("state", .{
        .root_source_file = .{ .src_path = .{ .owner = b, .sub_path = "src/state/main.zig" } },
        .target = target,
        .optimize = optimize,
    });

    const database_module = b.addModule("database", .{
        .root_source_file = .{ .src_path = .{ .owner = b, .sub_path = "src/database/main.zig" } },
        .target = target,
        .optimize = optimize,
    });

    const context_module = b.addModule("context", .{
        .root_source_file = .{ .src_path = .{ .owner = b, .sub_path = "src/context/main.zig" } },
        .target = target,
        .optimize = optimize,
    });

    const interpreter_module = b.addModule("interpreter", .{
        .root_source_file = .{ .src_path = .{ .owner = b, .sub_path = "src/interpreter/main.zig" } },
        .target = target,
        .optimize = optimize,
    });

    const precompile_module = b.addModule("precompile", .{
        .root_source_file = .{ .src_path = .{ .owner = b, .sub_path = "src/precompile/main.zig" } },
        .target = target,
        .optimize = optimize,
    });

    const handler_module = b.addModule("handler", .{
        .root_source_file = .{ .src_path = .{ .owner = b, .sub_path = "src/handler/main.zig" } },
        .target = target,
        .optimize = optimize,
    });

    const inspector_module = b.addModule("inspector", .{
        .root_source_file = .{ .src_path = .{ .owner = b, .sub_path = "src/inspector/main.zig" } },
        .target = target,
        .optimize = optimize,
    });

    const baremetal_module = b.addModule("baremetal", .{
        .root_source_file = .{ .src_path = .{ .owner = b, .sub_path = "src/baremetal/main.zig" } },
        .target = target,
        .optimize = optimize,
    });

    // Add module dependencies
    bytecode_module.addImport("primitives", primitives_module);
    state_module.addImport("primitives", primitives_module);
    state_module.addImport("bytecode", bytecode_module);
    database_module.addImport("primitives", primitives_module);
    database_module.addImport("state", state_module);
    database_module.addImport("bytecode", bytecode_module);
    context_module.addImport("primitives", primitives_module);
    context_module.addImport("state", state_module);
    context_module.addImport("database", database_module);
    interpreter_module.addImport("primitives", primitives_module);
    interpreter_module.addImport("bytecode", bytecode_module);
    interpreter_module.addImport("context", context_module);
    precompile_module.addImport("build_options", lib_options_module);
    precompile_module.addImport("primitives", primitives_module);
    handler_module.addImport("primitives", primitives_module);
    handler_module.addImport("bytecode", bytecode_module);
    handler_module.addImport("state", state_module);
    handler_module.addImport("database", database_module);
    handler_module.addImport("interpreter", interpreter_module);
    handler_module.addImport("context", context_module);
    handler_module.addImport("precompile", precompile_module);
    inspector_module.addImport("primitives", primitives_module);
    inspector_module.addImport("interpreter", interpreter_module);
    baremetal_module.addImport("primitives", primitives_module);

    // Zisk zkVM block transition executable (RV64IM target)
    const block_transition_zisk_exe = b.addExecutable(.{
        .name = "block_transition_zisk",
        .root_module = b.addModule("block_transition_zisk", .{
            .root_source_file = .{ .src_path = .{ .owner = b, .sub_path = "examples/block_transition_zisk.zig" } },
            .target = target,
            .optimize = optimize,
        }),
    });

    // Use custom linker script for zisk zkVM to place writable sections in RAM
    block_transition_zisk_exe.setLinkerScript(.{ .src_path = .{ .owner = b, .sub_path = "zisk.ld" } });

    // Use medany code model for full 64-bit address space access
    block_transition_zisk_exe.root_module.code_model = .medium;

    // Add build options
    block_transition_zisk_exe.root_module.addImport("build_options", lib_options_module);

    // Add all zevm modules
    block_transition_zisk_exe.root_module.addImport("baremetal", baremetal_module);
    block_transition_zisk_exe.root_module.addImport("primitives", primitives_module);
    block_transition_zisk_exe.root_module.addImport("bytecode", bytecode_module);
    block_transition_zisk_exe.root_module.addImport("state", state_module);
    block_transition_zisk_exe.root_module.addImport("database", database_module);
    block_transition_zisk_exe.root_module.addImport("context", context_module);
    block_transition_zisk_exe.root_module.addImport("interpreter", interpreter_module);
    block_transition_zisk_exe.root_module.addImport("precompile", precompile_module);
    block_transition_zisk_exe.root_module.addImport("handler", handler_module);
    block_transition_zisk_exe.root_module.addImport("inspector", inspector_module);

    // Install the executable
    b.installArtifact(block_transition_zisk_exe);

    // Default build step
    const default_step = b.getInstallStep();
    default_step.dependOn(&block_transition_zisk_exe.step);
}
