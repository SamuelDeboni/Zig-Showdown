const std = @import("std");
const network = @import("network");
const args = @import("args");
const zwl = @import("zwl");

const Game = @import("game.zig").Game;

const Resources = @import("game_resources.zig");

var gpa = std.heap.GeneralPurposeAllocator(.{}){};
const global_allocator = &gpa.allocator;

pub const WindowPlatform = zwl.Platform(.{
    .platforms_enabled = .{
        .x11 = (std.builtin.os.tag == .linux),
        .wayland = false,
        .windows = (std.builtin.os.tag == .windows),
    },
    .single_window = false,
    .render_software = true,
    .x11_use_xcb = false,
});

pub fn main() anyerror!u8 {
    defer _ = gpa.deinit();

    try network.init();
    defer network.deinit();

    var cli = args.parseForCurrentProcess(CliArgs, global_allocator) catch |err| switch (err) {
        error.EncounteredUnknownArgument => {
            try printUsage(std.io.getStdErr().writer());
            return 1;
        },
        else => |e| return e,
    };
    defer cli.deinit();

    if (cli.options.help) {
        try printUsage(std.io.getStdOut().writer());
        return 0;
    }

    // Do not init windowing before necessary. We don't need a window
    // for printing a help string.

    var platform = try WindowPlatform.init(global_allocator, .{});
    defer platform.deinit();

    var window = try platform.createWindow(.{
        .title = "Zig SHOWDOWN",
        .width = 1280,
        .height = 720,
        .resizeable = false,
        .track_damage = true,
        .visible = true,
    });
    defer window.deinit();

    var resources = Resources.init(global_allocator);
    defer resources.deinit();

    var game = try Game.init(global_allocator, &resources);
    defer game.deinit();

    game.current_state = .{
        .transition = .{
            .from = .splash,
            .to = .gameplay,
            .progress = 0.0,
            .style = .slice_bl_to_tr,
            .duration = 0.25,
        },
    };
    // game.current_state = .{ .state = .gameplay };

    //main_loop: while (true) {
    // const event = try platform.waitForEvent();

    // switch (event) {
    //     .WindowResized => |win| {
    //         const size = win.getSize();
    //         std.log.debug("*notices size {}x{}* OwO what's this", .{ size[0], size[1] });
    //     },

    //     // someone closed the window, just stop the game:
    //     .WindowDestroyed, .ApplicationTerminated => break :main_loop,

    //     .WindowDamaged => |damage| {
    //         std.log.debug("Taking damage: {}x{} @ {}x{}", .{ damage.w, damage.h, damage.x, damage.y });
    //     },
    // }

    {
        const pixbuf = try window.mapPixels();
        try game.render(pixbuf, 0.00);
        try window.submitPixels();
    }

    std.time.sleep(500 * std.time.ns_per_ms);

    while (true) {
        try game.update(0.01);

        const pixbuf = try window.mapPixels();
        try game.render(pixbuf, 0.01); // 10ms, not true, but ¯\_(ツ)_/¯
        try window.submitPixels();
    }

    return 0;
}

const CliArgs = struct {
    // In release mode, run the game in fullscreen by default,
    // otherwise use windowed mode
    fullscreen: bool = if (std.builtin.mode != .Debug)
        true
    else
        false,

    port: u16 = @import("build_options").default_port,

    help: bool = false,

    pub const shorthands = .{
        .f = "fullscreen",
    };
};

fn printUsage(writer: anytype) !void {
    try writer.writeAll(
        \\Someone should write this
    );
}
