package birb

import "core:log"
_ :: log

import "shared:svk"

VIEW_DISTANCE :: 1
NR_CHUNKS :: (1 + 2 * VIEW_DISTANCE) * (1 + 2 * VIEW_DISTANCE)

init_visible_chunks :: proc(ctx: svk.Context, position: [3]f32) -> (meshes: [9]Mesh) {
	chunk_x := cast(int)position.x / cast(int)CHUNK_SIZE
	chunk_y := cast(int)position.z / cast(int)CHUNK_SIZE
	chunk_coords := [2]int{chunk_x, chunk_y}

	index := 0
	offsets := [3]int{0, -1, 1}

	for y_offset in offsets {
		for x_offset in offsets {
			offset := [2]int{x_offset, y_offset}
			meshes[index] = generate_chunk_mesh(ctx, 1, chunk_coords + offset)

			index += 1
		}
	}

	return meshes
}

update_visible_chunks :: proc(
	ctx: svk.Context,
	position: [3]f32,
	prev_chunk_meshes: ^[9]Mesh,
) -> (
	meshes: [9]Mesh,
) {
	chunk_x := cast(int)position.x / cast(int)CHUNK_SIZE
	chunk_y := cast(int)position.z / cast(int)CHUNK_SIZE
	chunk_coords := [2]int{chunk_x, chunk_y}

	index := 0
	offsets := [3]int{0, -1, 1}

	prev_center_chunk := prev_chunk_meshes[0].chunk_coords

	if prev_center_chunk == chunk_coords {
		return prev_chunk_meshes^
	}

	distance_to_prev := chunk_coords - prev_center_chunk

	for y_offset in offsets {
		for x_offset in offsets {
			offset := [2]int{x_offset, y_offset}
			prev_offset := distance_to_prev + offset

			if abs(prev_offset.x) <= 1 && abs(prev_offset.y) <= 1 {
				y_index := 0
				if prev_offset.y == -1 {
					y_index = 1
				} else if prev_offset.y == 1 {
					y_index = 2
				}

				x_index := 0
				if prev_offset.x == -1 {
					x_index = 1
				} else if prev_offset.x == 1 {
					x_index = 2
				}

				prev_mesh_index := 3 * y_index + x_index
				meshes[index] = prev_chunk_meshes[prev_mesh_index]
				prev_chunk_meshes[prev_mesh_index]._was_copied = true
			} else {
				meshes[index] = generate_chunk_mesh(ctx, 1, chunk_coords + offset)
			}

			index += 1
		}
	}

	for mesh in prev_chunk_meshes {
		if mesh._was_copied {continue}
		destroy_mesh_buffers(ctx, mesh)
	}

	return meshes
}
