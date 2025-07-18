package birb

import "core:thread"

import "shared:svk"

VIEW_DISTANCE :: 1
CHUNKS_PER_ROW :: 1 + 2 * VIEW_DISTANCE // also per column cuz thats how squares work
N :: CHUNKS_PER_ROW

update_chunks_worker :: proc(_: ^thread.Thread) {
	data := cast(^Render_Data)context.user_ptr

	update_current_chunks(data)
	generate_future_chunks(data)
}

update_current_chunks :: proc(data: ^Render_Data) {
	meshes: [N][N]Mesh

	offsets := [3]int{0, -1, 1}
	levels_of_detail := [7]u32{1, 2, 4, 6, 8, 10, 12}

	prev_offset := data.center_coords - data._prev_center_coords

	for y_offset in offsets {
		for x_offset in offsets {
			max_offset := max(abs(x_offset), abs(y_offset))
			lod := levels_of_detail[max_offset]

			offset := [2]int{x_offset, y_offset}
			current_prev_offset := prev_offset + offset
			prev := current_prev_offset

			prev_mesh := &data.meshes[prev.y][prev.x]
			pregenerated_mesh := &data.pregenerated_meshes[prev.y][prev.x]

			new_mesh := &meshes[offset.y][offset.x]

			if lod == prev_mesh.lod && !data._first_frame {
				new_mesh^ = prev_mesh^
				prev_mesh._was_copied = true
			} else if lod == pregenerated_mesh.lod && !data._first_frame {
				new_mesh^ = pregenerated_mesh^
				pregenerated_mesh._was_copied = true
			} else {
				new_mesh^ = generate_chunk_mesh(data.ctx^, lod, data.center_coords + offset)
			}
		}
	}

	prev_meshes := data.meshes
	data.meshes = meshes

	for &row in prev_meshes {
		for &mesh in row {
			if mesh._was_copied {continue}
			destroy_mesh_buffers(data.ctx^, mesh)
		}
	}

	for &row in data.pregenerated_meshes {
		for &mesh in row {
			if mesh._was_copied {continue}
			destroy_mesh_buffers(data.ctx^, mesh)
		}
	}

	data.meshes = meshes
}

generate_future_chunks :: proc(data: ^Render_Data) {
	offsets := [3]int{0, -1, 1}
	// levels_of_detail := [7]u32{1, 2, 4, 6, 8, 10, 12}

	for y_offset in offsets {
		for x_offset in offsets {
			offset := [2]int{x_offset, y_offset}
			mesh := &data.meshes[offset.y][offset.x]

			pregenerated_lod: u32
			switch mesh.lod {
			case 1:
				pregenerated_lod = 2
			case 2:
				pregenerated_lod = 1
			case 4, 6, 8, 10, 12:
				pregenerated_lod = mesh.lod - 2
			}

			data.pregenerated_meshes[offset.y][offset.x] = generate_chunk_mesh(
				data.ctx^,
				pregenerated_lod,
				data.center_coords + offset,
			)
		}
	}
}
