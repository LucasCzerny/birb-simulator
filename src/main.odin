package birb

import "core:log"
import "core:mem"
import "core:thread"

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
		center_coords      = {0, 0},
		is_running         = true,
	}

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

	chunks_data := Chunk_Thread_Data {
		temp_ctx = svk.Context{device = ctx.device, physical_device = ctx.physical_device},
		first_frame = true,
	}

	chunks_thread := thread.create_and_start_with_data(&chunks_data, chunks_worker, context)
	defer thread.destroy(chunks_thread)

	for !glfw.WindowShouldClose(ctx.window.handle) {
		svk.wait_until_frame_is_done(ctx, draw_ctx)
		delta_time := svk.delta_time()

		if chunks_data.copy_meshes {
			chunks_data.copy_meshes = false

			if !chunks_data.first_frame {
				data.waiting_for_deletion[chunks_data.free_slot_deletion] = {
					countdown           = 2,
					initialized         = true,
					meshes              = data.meshes,
					pregenerated_meshes = chunks_data.pregenerated_meshes,
				}

				chunks_data.free_slot_deletion += 1
				chunks_data.free_slot_deletion %= MAX_FRAMES_IN_FLIGHT
			}

			data.meshes = chunks_data.meshes
		}

		for &old_chunks in data.waiting_for_deletion {
			if !old_chunks.initialized {continue}
			old_chunks.countdown -= 1

			if old_chunks.countdown <= 0 {
				old_chunks.initialized = false
				old_chunks.countdown = 0
				destroy_old_chunks(chunks_data.temp_ctx, &old_chunks)
			}
		}

		update_camera(ctx, &data.camera, delta_time, data.loaded)

		for i in 0 ..< MAX_FRAMES_IN_FLIGHT {
			if !data.loaded {continue}
			svk.copy_to_buffer(ctx, &data.camera_buffers[i], &data.camera)
		}

		svk.draw(&ctx, &draw_ctx, &data.pipeline)

		glfw.SwapBuffers(ctx.window.handle)
		glfw.PollEvents()
	}

	data.is_running = false

	vk.DeviceWaitIdle(ctx.device)
	svk.destroy_graphics_pipeline(ctx, data.pipeline)
	svk.destroy_descriptor_group_layout(ctx, data.camera_descriptors)

	for &row in data.meshes {
		for &mesh in row {
			destroy_mesh_buffers(ctx, mesh)
		}
	}

	for &row in chunks_data.pregenerated_meshes {
		for &mesh in row {
			destroy_mesh_buffers(ctx, mesh)
		}
	}

	for i in 0 ..< MAX_FRAMES_IN_FLIGHT {
		svk.unmap_buffer(ctx, &data.camera_buffers[i])
		svk.destroy_buffer(ctx, data.camera_buffers[i])
	}

	svk.destroy_context(ctx)
	svk.destroy_draw_context(ctx, draw_ctx)
}

destroy_old_chunks :: proc(ctx: svk.Context, old_chunks: ^Old_Chunks) {
	log.info("deleting around", old_chunks.meshes[1][1].chunk_coords)

	for y in 0 ..< N {
		for x in 0 ..< N {
			prev_mesh := &old_chunks.meshes[y][x]
			pregenerated_mesh := &old_chunks.pregenerated_meshes[y][x]

			if !prev_mesh._was_copied {
				destroy_mesh_buffers(ctx, prev_mesh^)
			}

			if !pregenerated_mesh._was_copied {
				destroy_mesh_buffers(ctx, pregenerated_mesh^)
			}
		}
	}
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
