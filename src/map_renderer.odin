package birb

import vk "vendor:vulkan"

import "shared:svk"

Render_Data :: struct {
	pipeline:           svk.Pipeline,
	meshes:             [9]Mesh,
	camera:             Camera,
	camera_buffers:     [MAX_FRAMES_IN_FLIGHT]svk.Buffer,
	camera_descriptors: svk.Descriptor_Group,
}

create_pipeline :: proc(ctx: svk.Context, data: Render_Data) -> svk.Pipeline {
	layouts := [1]vk.DescriptorSetLayout{data.camera_descriptors.layout}

	push_constant_range := vk.PushConstantRange {
		stageFlags = {.VERTEX},
		offset     = 0,
		size       = 3 * size_of(f32),
	}

	layout_info := vk.PipelineLayoutCreateInfo {
		sType                  = .PIPELINE_LAYOUT_CREATE_INFO,
		setLayoutCount         = 1,
		pSetLayouts            = raw_data(layouts[:]),
		pushConstantRangeCount = 1,
		pPushConstantRanges    = &push_constant_range,
	}

	attachments: [2]vk.AttachmentDescription

	// color attachment
	attachments[0] = vk.AttachmentDescription {
		format         = ctx.swapchain.surface_format.format,
		samples        = {._1},
		loadOp         = .CLEAR,
		storeOp        = .STORE,
		stencilLoadOp  = .DONT_CARE,
		stencilStoreOp = .DONT_CARE,
		initialLayout  = .UNDEFINED,
		finalLayout    = .PRESENT_SRC_KHR,
	}

	color_reference := vk.AttachmentReference {
		attachment = 0,
		layout     = .COLOR_ATTACHMENT_OPTIMAL,
	}

	// depth attachment
	attachments[1] = vk.AttachmentDescription {
		format         = ctx.swapchain.depth_format,
		samples        = {._1},
		loadOp         = .CLEAR,
		storeOp        = .DONT_CARE,
		stencilLoadOp  = .DONT_CARE,
		stencilStoreOp = .DONT_CARE,
		initialLayout  = .UNDEFINED,
		finalLayout    = .DEPTH_STENCIL_ATTACHMENT_OPTIMAL,
	}

	depth_reference := vk.AttachmentReference {
		attachment = 1,
		layout     = .DEPTH_STENCIL_ATTACHMENT_OPTIMAL,
	}

	subpass := vk.SubpassDescription {
		pipelineBindPoint       = .GRAPHICS,
		colorAttachmentCount    = 1,
		pColorAttachments       = &color_reference,
		pDepthStencilAttachment = &depth_reference,
	}

	subpass_dependency := vk.SubpassDependency {
		srcSubpass    = vk.SUBPASS_EXTERNAL,
		dstSubpass    = 0,
		srcStageMask  = {.COLOR_ATTACHMENT_OUTPUT, .EARLY_FRAGMENT_TESTS},
		dstStageMask  = {.COLOR_ATTACHMENT_OUTPUT, .EARLY_FRAGMENT_TESTS},
		srcAccessMask = {},
		dstAccessMask = {.COLOR_ATTACHMENT_WRITE, .DEPTH_STENCIL_ATTACHMENT_WRITE},
	}

	render_pass_info := vk.RenderPassCreateInfo {
		sType           = .RENDER_PASS_CREATE_INFO,
		attachmentCount = 2,
		pAttachments    = raw_data(attachments[:]),
		subpassCount    = 1,
		pSubpasses      = &subpass,
		dependencyCount = 1,
		pDependencies   = &subpass_dependency,
	}

	vertex_description := vk.VertexInputBindingDescription {
		binding   = 0,
		stride    = size_of(Vertex),
		inputRate = .VERTEX,
	}

	vertex_attributes := [2]vk.VertexInputAttributeDescription {
		{location = 0, binding = 0, format = .R32G32B32_SFLOAT, offset = 0},
		{location = 1, binding = 0, format = .R32G32B32_SFLOAT, offset = size_of([3]f32)},
	}

	config := svk.Graphics_Pipeline_Config {
		pipeline_layout_info   = layout_info,
		render_pass_info       = render_pass_info,
		vertex_shader_source   = #load("../shaders/map.vert.spv", []u32),
		fragment_shader_source = #load("../shaders/map.frag.spv", []u32),
		binding_descriptions   = {vertex_description},
		attribute_descriptions = vertex_attributes[:],
		subpass                = 0,
		clear_color            = {0.1, 0.3, 0.6},
		record_fn              = record_map_rendering,
	}

	return svk.create_graphics_pipeline(ctx, config)
}

create_camera_buffers :: proc(ctx: svk.Context) -> (buffers: [MAX_FRAMES_IN_FLIGHT]svk.Buffer) {
	for i in 0 ..< len(buffers) {
		buffers[i] = svk.create_buffer(
			ctx,
			size_of(Camera),
			1,
			{.UNIFORM_BUFFER},
			{.DEVICE_LOCAL, .HOST_COHERENT},
		)
	}

	return buffers
}

create_camera_descriptors :: proc(ctx: svk.Context) -> svk.Descriptor_Group {
	binding := vk.DescriptorSetLayoutBinding {
		binding         = 0,
		descriptorType  = .UNIFORM_BUFFER,
		descriptorCount = 1,
		stageFlags      = {.VERTEX, .FRAGMENT},
	}

	return svk.create_descriptor_group(ctx, {binding}, MAX_FRAMES_IN_FLIGHT)
}

@(private = "file")
record_map_rendering :: proc(
	ctx: svk.Context,
	pipeline: svk.Pipeline,
	command_buffer: vk.CommandBuffer,
	current_frame: u32,
) {
	data := cast(^Render_Data)context.user_ptr

	svk.bind_descriptor_set(
		ctx,
		svk.get_set(data.camera_descriptors, cast(int)current_frame),
		command_buffer,
		pipeline.layout,
		.GRAPHICS,
		0,
	)

	offset: vk.DeviceSize = 0

	for &mesh in data.meshes {
		offsets_and_lod := [3]f32 {
			cast(f32)mesh.chunk_coords.x * 240,
			cast(f32)mesh.chunk_coords.y * 240,
			cast(f32)mesh.lod,
		}

		vk.CmdPushConstants(
			command_buffer,
			pipeline.layout,
			{.VERTEX},
			0,
			3 * size_of(f32),
			raw_data(offsets_and_lod[:]),
		)

		vk.CmdBindVertexBuffers(command_buffer, 0, 1, &mesh.vertex_buffer.handle, &offset)
		vk.CmdBindIndexBuffer(command_buffer, mesh.index_buffer.handle, offset, .UINT32)

		vk.CmdDrawIndexed(command_buffer, mesh.index_buffer.count * 3, 1, 0, 0, 0)
	}
}
