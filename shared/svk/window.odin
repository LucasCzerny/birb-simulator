package svk

import "core:log"

import sdl "vendor:sdl3"
import vk "vendor:vulkan"

Window_Config :: struct {
	window_title:     cstring,
	initial_width:    i32,
	initial_height:   i32,
	resizable:        bool,
	fullscreen:       bool,
	sdl_init_flags:   sdl.InitFlags,
	sdl_window_flags: sdl.WindowFlags,
}

Window :: struct {
	handle:  ^sdl.Window,
	surface: vk.SurfaceKHR,
	width:   i32,
	height:  i32,
}

create_window :: proc(window: ^Window, config: Window_Config, instance: vk.Instance) {
	window_flags: sdl.WindowFlags = {.VULKAN} + config.sdl_window_flags
	if config.fullscreen {
		window_flags += {.FULLSCREEN}
	}

	window.handle = sdl.CreateWindow(
		config.window_title,
		config.initial_width,
		config.initial_height,
		window_flags,
	)
	log.ensure(window.handle != nil, "Failed to create the SDL3 window")

	window.width = config.initial_width
	window.height = config.initial_height

	surface_ok := sdl.Vulkan_CreateSurface(window.handle, instance, nil, &window.surface)
	log.ensure(surface_ok, "Failed to create the SDL3 surface")
}

destroy_window :: proc(ctx: Context, window: Window) {
	sdl.DestroyWindow(window.handle)
	sdl.Vulkan_DestroySurface(ctx.instance, window.surface, nil)
}

