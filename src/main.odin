package birb

import "core:log"
import "core:mem"

import "shared:svk"

import "vendor:glfw"
import vk "vendor:vulkan"

MAX_FRAMES_IN_FLIGHT :: 2

main :: proc() {
	when ODIN_DEBUG {
		context.logger = log.create_console_logger(
			opt = {.Level, .Short_File_Path, .Line, .Procedure, .Terminal_Color},
		)
		defer log.destroy_console_logger(context.logger)
	}

	when ODIN_DEBUG {
		tracking_allocator: mem.Tracking_Allocator
		mem.tracking_allocator_init(&tracking_allocator, context.allocator)
		context.allocator = mem.tracking_allocator(&tracking_allocator)

		defer {
			for _, entry in tracking_allocator.allocation_map {
				context.logger = {}
				log.warnf("%v leaked %d bytes", entry.location, entry.size)
			}

			for entry in tracking_allocator.bad_free_array {
				context.logger = {}
				log.warnf("%v bad free on %v", entry.location, entry.memory)
			}

			mem.tracking_allocator_destroy(&tracking_allocator)
		}
	}

	ctx := create_context()
	draw_ctx := svk.create_draw_context(ctx, MAX_FRAMES_IN_FLIGHT)

	data := Render_Data {
		camera             = create_camera(ctx),
		camera_descriptors = create_camera_descriptors(ctx),
		camera_buffers     = create_camera_buffers(ctx),
	}

	data.meshes = init_visible_chunks(ctx, data.camera.position)

	for i in 0 ..< MAX_FRAMES_IN_FLIGHT {
		svk.update_descriptor_set(
			ctx,
			svk.get_set(data.camera_descriptors, i),
			data.camera_buffers[i],
			0,
		)

		svk.map_buffer(ctx, &data.camera_buffers[i])
	}

	data.pipeline = create_pipeline(ctx, data)
	context.user_ptr = &data

	for !glfw.WindowShouldClose(ctx.window.handle) {
		svk.wait_until_frame_is_done(ctx, draw_ctx)
		delta_time := svk.delta_time()

		changed := update_camera(ctx, &data.camera, delta_time)
		if changed {
			for i in 0 ..< MAX_FRAMES_IN_FLIGHT {
				svk.copy_to_buffer(ctx, &data.camera_buffers[i], &data.camera)
			}
		}

		data.meshes = update_visible_chunks(ctx, data.camera.position, &data.meshes)

		svk.draw(&ctx, &draw_ctx, &data.pipeline)

		glfw.SwapBuffers(ctx.window.handle)
		glfw.PollEvents()
	}

	vk.DeviceWaitIdle(ctx.device)
	svk.destroy_graphics_pipeline(ctx, data.pipeline)
	svk.destroy_descriptor_group_layout(ctx, data.camera_descriptors)

	for mesh in data.meshes {
		destroy_mesh_buffers(ctx, mesh)
	}

	for i in 0 ..< MAX_FRAMES_IN_FLIGHT {
		svk.unmap_buffer(ctx, &data.camera_buffers[i])
		svk.destroy_buffer(ctx, data.camera_buffers[i])
	}

	svk.destroy_context(ctx)
	svk.destroy_draw_context(ctx, draw_ctx)
}

create_context :: proc() -> svk.Context {
	instance_config :: svk.Instance_Config {
		name                     = "birb",
		major                    = 0,
		minor                    = 1,
		patch                    = 0,
		extensions               = {"VK_EXT_debug_utils"},
		enable_validation_layers = true,
	}

	window_config :: svk.Window_Config {
		window_title   = "birb",
		initial_width  = 1280,
		initial_height = 720,
		resizable      = true,
		fullscreen     = false,
	}

	device_config := svk.Device_Config {
		extensions = {"VK_KHR_swapchain"},
		features = {samplerAnisotropy = true},
	}

	swapchain_config :: svk.Swapchain_Config {
		format       = .B8G8R8A8_SRGB,
		color_space  = .COLORSPACE_SRGB_NONLINEAR,
		present_mode = .MAILBOX,
	}

	commands_config :: svk.Commands_Config {
		nr_command_buffers = MAX_FRAMES_IN_FLIGHT,
	}

	descriptor_config :: svk.Descriptor_Config {
		max_sets          = MAX_FRAMES_IN_FLIGHT,
		nr_uniform_buffer = MAX_FRAMES_IN_FLIGHT,
	}

	return svk.create_context(
		instance_config,
		window_config,
		device_config,
		swapchain_config,
		commands_config,
		descriptor_config,
	)
}
