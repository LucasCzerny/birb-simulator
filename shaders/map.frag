#version 450

layout(location = 0) in float height;
layout(location = 1) in vec3 normal;
layout(location = 2) in vec3 vertex_position;
layout(location = 3) in vec3 position_relative_to_cam;

layout(location = 0) out vec4 output_color;

layout(set = 0, binding = 0) uniform Camera {
    mat4 view;
    mat4 projection;
    vec3 direction;
} camera;

const int NR_LAYERS = 5;
layout(set = 1, binding = 0) uniform sampler2D albedo_textures[NR_LAYERS];
layout(set = 1, binding = 1) uniform sampler2D normal_textures[NR_LAYERS];

const int CHUNK_SIZE = 240;
const int CHUNK_SCALE = 5;
const int REAL_CHUNK_SIZE = CHUNK_SIZE * CHUNK_SCALE;

const float FOG_CUTOFF_DISTANCE = 3000.0;
const float FOG_MAX_DISTANCE = 6000.0;

const float cutoff_heights[5] = {
    -5.0, 10.0, 50.0, 300.0, 1000.0
};
   
float lighting(vec3 normal, vec3 view_dir);
vec3 triplanar(int texture_index);

void main() {
    vec3 color;
    for (int i = 0; i < 5; i++) {
        if (height > cutoff_heights[i]) continue;

        vec3 current_color = triplanar(i);
        if (i == 0) {
            color = 0.5 * current_color;
            break;
        }

        vec3 prev_color = triplanar(i - 1);
        if (i == 1) {
            prev_color *= 0.5;
        }

        color = mix(prev_color, current_color, (height - cutoff_heights[i - 1]) / (cutoff_heights[i] - cutoff_heights[i - 1]));
        break;
    }

    float intensity = lighting(normal, camera.direction);
    vec4 terrain_color = vec4(intensity * color, 1.0);

    float distance_to_camera = length(position_relative_to_cam);
    float fog_multiplier = (distance_to_camera - FOG_CUTOFF_DISTANCE) / (FOG_MAX_DISTANCE - FOG_CUTOFF_DISTANCE);
    fog_multiplier = max(fog_multiplier, 0);
    fog_multiplier = fog_multiplier * fog_multiplier;

    output_color = mix(terrain_color, vec4(1.0, 1.0, 1.0, 0.0), fog_multiplier);
}

float lighting(vec3 normal, vec3 view_dir) {
    const vec3 light_direction = normalize(vec3(0.5, 1.0, 0.0));
    normal = normalize(normal);
    view_dir = normalize(view_dir);
    
    const float ambient = 0.1;
    const float diffuse_strength = 0.6;
    const float specular_strength = 0.3;
    const float shininess = 32.0;

    const float diffuse = diffuse_strength * max(dot(normal, light_direction), 0.0);

    const vec3 halfway_dir = normalize(light_direction + view_dir);
    const float spec = pow(max(dot(normal, halfway_dir), 0.0), shininess);
    const float specular = specular_strength * spec;

    return ambient + diffuse + specular;
}

vec3 triplanar(int texture_index) {
    vec3 yz_component = texture(albedo_textures[texture_index], vertex_position.yz / float(REAL_CHUNK_SIZE)).rgb;
    vec3 xz_component = texture(albedo_textures[texture_index], vertex_position.xz / float(REAL_CHUNK_SIZE)).rgb;
    vec3 xy_component = texture(albedo_textures[texture_index], vertex_position.xy / float(REAL_CHUNK_SIZE)).rgb;

    vec3 abs_normal = abs(normal);
    vec3 color = abs_normal.x * yz_component + abs_normal.y * xz_component + abs_normal.z * xy_component;

    return color;
}

