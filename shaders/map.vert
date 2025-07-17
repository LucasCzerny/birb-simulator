#version 450

layout(location = 0) in vec3 position;
layout(location = 1) in vec3 normal;

layout(location = 0) out float height_out;
layout(location = 1) out vec3 normal_out;
layout(location = 2) out vec3 mesh_color_out;

layout(set = 0, binding = 0) uniform Camera {
    mat4 view;
    mat4 projection;
    vec3 direction;
} camera;

layout(push_constant) uniform Offsets {
    float x_offset;
    float y_offset;
    float lod;
};

void main() {
    height_out = position.y;
    normal_out = normal;

    mesh_color_out = vec3(1.0, 0.0, 0.0);
    if (lod == 2.0) {
        mesh_color_out = vec3(0.0, 1.0, 0.0);
    } else if (lod == 4.0) {
        mesh_color_out = vec3(0.0, 0.0, 1.0);
    }

    vec3 the_cooler_position = vec3(position.x + x_offset, position.y, position.z + y_offset);
    gl_Position = camera.projection * camera.view * vec4(the_cooler_position, 1.0);
}
