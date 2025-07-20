package birb

import "core:log"

import "core:math/linalg"
import "core:math/noise"

import "shared:svk"

CHUNK_SIZE: u32 : 240 // divisible by 1, 2, 4, 6, 8, 10, 12 :)
HEIGHT_SCALE :: 2

Mesh :: struct {
	chunk_coords:  [2]int,
	lod:           u32,
	vertex_buffer: svk.Buffer,
	index_buffer:  svk.Buffer,
	_was_copied:   bool,
}

Vertex :: struct {
	position: [3]f32,
	normal:   [3]f32,
}

generate_chunk_mesh :: proc(ctx: svk.Context, lod: u32, chunk_coords: [2]int) -> Mesh {
	log.assert(
		lod == 1 || lod == 2 || lod == 4 || lod == 6 || lod == 8 || lod == 10 || lod == 12,
		"Invalid value for lod",
	)

	// last loop iteration doesn't generate a triangle -> size of mesh is CHUNK_SIZE
	width, height: u32 = CHUNK_SIZE + 1, CHUNK_SIZE + 1
	shift := cast(int)CHUNK_SIZE / 2

	height_map := generate_height_map(
		width,
		height,
		seed = 69420,
		offset = shift * chunk_coords,
		zoom = 500,
		octaves = 5,
		persistance = 0.4,
		lacunarity = 2.2,
		height_multiplier = 50,
	)

	defer delete(height_map)

	vertices_per_line := (CHUNK_SIZE) / lod + 1
	vertices := make([]Vertex, vertices_per_line * vertices_per_line)
	indices := make([][3]u32, 2 * (vertices_per_line - 1) * (vertices_per_line - 1))

	current_vertex: u32 = 0
	current_index: u32 = 0

	for y: u32 = 0; y < height; y += lod {
		for x: u32 = 0; x < width; x += lod {
			vertex_height := height_map[y][x] * HEIGHT_SCALE

			vertices[current_vertex].position = [3]f32{f32(x), vertex_height, f32(y)}

			if x < width - 1 && y < height - 1 {
				// a *--* b
				//   | /
				// c *
				indices[current_index] = [3]u32 {
					current_vertex,
					current_vertex + vertices_per_line,
					current_vertex + 1,
				}

				//      * b
				//    / |
				// c *--* a
				indices[current_index + 1] = [3]u32 {
					current_vertex + vertices_per_line + 1,
					current_vertex + 1,
					current_vertex + vertices_per_line,
				}

				current_index += 2
			}

			current_vertex += 1
		}
	}

	for triangle in indices {
		a := vertices[triangle[0]].position
		b := vertices[triangle[1]].position
		c := vertices[triangle[2]].position

		normal := linalg.vector_cross3(b - a, c - a)

		vertices[triangle[0]].normal += normal
		vertices[triangle[1]].normal += normal
		vertices[triangle[2]].normal += normal
	}

	for &vertex in vertices {
		vertex.normal = linalg.normalize(vertex.normal)
	}

	log.assert(current_vertex == cast(u32)len(vertices), "Your math is wrong lmaooo")
	log.assert(current_index == cast(u32)len(indices), "Your math is wrong lmaooo")

	mesh := create_mesh_buffers(ctx, vertices, indices)
	mesh.lod = lod
	mesh.chunk_coords = chunk_coords

	return mesh
}

destroy_mesh_buffers :: proc(ctx: svk.Context, mesh: Mesh) {
	svk.destroy_buffer(ctx, mesh.vertex_buffer)
	svk.destroy_buffer(ctx, mesh.index_buffer)
}

@(private = "file")
create_mesh_buffers :: proc(
	ctx: svk.Context,
	vertices: []Vertex,
	indices: [][3]u32,
) -> (
	mesh: Mesh,
) {
	mesh.vertex_buffer = svk.create_buffer(
		ctx,
		size_of(Vertex),
		cast(u32)len(vertices),
		{.VERTEX_BUFFER},
		{.DEVICE_LOCAL, .HOST_COHERENT},
	)

	mesh.index_buffer = svk.create_buffer(
		ctx,
		size_of([3]u32),
		cast(u32)len(indices),
		{.INDEX_BUFFER},
		{.DEVICE_LOCAL, .HOST_COHERENT},
	)

	svk.copy_to_buffer(ctx, &mesh.vertex_buffer, raw_data(vertices))
	svk.copy_to_buffer(ctx, &mesh.index_buffer, raw_data(indices))

	return mesh
}

@(private = "file")
generate_height_map :: proc(
	width, height: u32,
	seed: i64,
	offset: [2]int,
	zoom: f32,
	octaves: u32,
	persistance, lacunarity: f32,
	height_multiplier: f32,
) -> [][]f32 {
	log.assert(width > 1 && height > 1, "Height map must be at least 1x1")
	log.assert(zoom > 0, "Zoom must be positive")
	log.assert(0 <= persistance && persistance <= 1, "Persistance has to be in [0, 1]")

	height_map := make([][]f32, height)

	center_x := width / 2
	center_y := height / 2

	for &row, y in height_map {
		row = make([]f32, width)

		for &value, x in row {
			amplitude: f32 = 1
			frequency: f32 = 1
			noise_height: f32 = 0

			for _ in 0 ..< octaves {
				sample_x := f32(x - int(center_x) + offset.x) * frequency
				sample_y := f32(y - int(center_y) + offset.y) * frequency
				sample := [2]f64{f64(sample_x) / f64(zoom), f64(sample_y) / f64(zoom)}

				perlin := noise.noise_2d(seed, sample)
				noise_height += perlin * amplitude

				amplitude *= persistance
				frequency *= lacunarity
			}

			value = height_multiplier * noise_height
		}
	}

	return height_map
}
