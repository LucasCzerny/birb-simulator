package birb

import vk "vendor:vulkan"

import "shared:svk"

NR_LAYERS :: 5

Render_Data :: struct {
	pipeline:             svk.Pipeline,
	camera:               Camera,
	camera_buffers:       [MAX_FRAMES_IN_FLIGHT]svk.Buffer,
	camera_descriptors:   svk.Descriptor_Group,
	//
	is_running:           bool,
	//
	meshes:               [N][N]Mesh,
	center_coords:        [2]int,
	waiting_for_deletion: [MAX_FRAMES_IN_FLIGHT]Old_Chunks,
	center_height_map:    [][]f32,
	//
	albedo_textures:      [NR_LAYERS]svk.Image,
	normal_textures:      [NR_LAYERS]svk.Image,
	sampler:              vk.Sampler,
	textures_descriptor:  svk.Descriptor_Set,
}

Old_Chunks :: struct {
	countdown:           int,
	initialized:         bool,
	meshes:              [N][N]Mesh,
	pregenerated_meshes: [N][N]Mesh,
}

create_pipeline :: proc(ctx: svk.Context, data: Render_Data) -> svk.Pipeline {
	layouts := [2]vk.DescriptorSetLayout {
		data.camera_descriptors.layout,
		data.textures_descriptor.layout,
	}

	push_constant_range := vk.PushConstantRange {
		stageFlags = {.VERTEX},
		offset     = 0,
		size       = 2 * size_of(f32),
	}

	layout_info := vk.PipelineLayoutCreateInfo {
		sType                  = .PIPELINE_LAYOUT_CREATE_INFO,
		setLayoutCount         = len(layouts),
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

	color_blend_attachment := vk.PipelineColorBlendAttachmentState {
		blendEnable         = true,
		srcColorBlendFactor = .SRC_ALPHA,
		dstColorBlendFactor = .ONE_MINUS_SRC_ALPHA,
		colorBlendOp        = .ADD,
		srcAlphaBlendFactor = .ONE,
		dstAlphaBlendFactor = .ONE_MINUS_SRC_ALPHA,
		alphaBlendOp        = .ADD,
		colorWriteMask      = {.R, .G, .B, .A},
	}

	config := svk.Graphics_Pipeline_Config {
		pipeline_layout_info   = layout_info,
		render_pass_info       = render_pass_info,
		vertex_shader_source   = #load("../shaders/map.vert.spv", []u32),
		fragment_shader_source = #load("../shaders/map.frag.spv", []u32),
		binding_descriptions   = {vertex_description},
		attribute_descriptions = vertex_attributes[:],
		color_blend_attachment = color_blend_attachment,
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

create_camera_descriptors :: proc(
	ctx: svk.Context,
	camera_buffers: ^[MAX_FRAMES_IN_FLIGHT]svk.Buffer,
) -> svk.Descriptor_Group {
	binding := vk.DescriptorSetLayoutBinding {
		binding         = 0,
		descriptorType  = .UNIFORM_BUFFER,
		descriptorCount = 1,
		stageFlags      = {.VERTEX, .FRAGMENT},
	}

	descriptor_group := svk.create_descriptor_group(ctx, {binding}, MAX_FRAMES_IN_FLIGHT)

	for i in 0 ..< MAX_FRAMES_IN_FLIGHT {
		svk.update_descriptor_set(ctx, svk.get_set(descriptor_group, i), camera_buffers[i], 0)
		svk.map_buffer(ctx, &camera_buffers[i])
	}

	return descriptor_group
}

create_texture_descriptor :: proc(
	ctx: svk.Context,
	sampler: vk.Sampler,
	albedo_textures, normal_textures: ^[NR_LAYERS]svk.Image,
) -> svk.Descriptor_Set {
	albedo_binding := vk.DescriptorSetLayoutBinding {
		binding         = 0,
		descriptorType  = .COMBINED_IMAGE_SAMPLER,
		descriptorCount = NR_LAYERS,
		stageFlags      = {.FRAGMENT},
	}

	normal_binding := vk.DescriptorSetLayoutBinding {
		binding         = 1,
		descriptorType  = .COMBINED_IMAGE_SAMPLER,
		descriptorCount = NR_LAYERS,
		stageFlags      = {.FRAGMENT},
	}

	descriptor_set := svk.create_descriptor_set(ctx, {albedo_binding, normal_binding})

	for i in 0 ..< NR_LAYERS {
		svk.update_descriptor_set_image(
			ctx,
			descriptor_set,
			sampler,
			albedo_textures[i],
			0,
			cast(u32)i,
		)

		svk.update_descriptor_set_image(
			ctx,
			descriptor_set,
			sampler,
			normal_textures[i],
			1,
			cast(u32)i,
		)
	}

	return descriptor_set
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

	svk.bind_descriptor_set(
		ctx,
		data.textures_descriptor,
		command_buffer,
		pipeline.layout,
		.GRAPHICS,
		1,
	)

	offset: vk.DeviceSize = 0

	for &row in data.meshes {
		for &mesh in row {
			if mesh.vertex_buffer.handle == 0 {
				continue
			}

			mesh_offset := [2]f32 {
				cast(f32)mesh.chunk_coords.x * cast(f32)REAL_CHUNK_SIZE,
				cast(f32)mesh.chunk_coords.y * cast(f32)REAL_CHUNK_SIZE,
			}

			vk.CmdPushConstants(
				command_buffer,
				pipeline.layout,
				{.VERTEX},
				0,
				size_of([2]f32),
				raw_data(mesh_offset[:]),
			)

			vk.CmdBindVertexBuffers(command_buffer, 0, 1, &mesh.vertex_buffer.handle, &offset)
			vk.CmdBindIndexBuffer(command_buffer, mesh.index_buffer.handle, offset, .UINT32)

			vk.CmdDrawIndexed(command_buffer, mesh.index_buffer.count * 3, 1, 0, 0, 0)
		}
	}
}

