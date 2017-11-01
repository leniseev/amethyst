// TODO: Needs documentation.

#version 150 core

layout (std140) uniform FragmentArgs {
    int point_light_count;
    int directional_light_count;
};

struct PointLight {
    vec4 position;
    vec4 color;
    float intensity;
    float radius;
    float smoothness;
    float _pad;
};

layout (std140) uniform PointLights {
    PointLight plight[128];
};

struct DirectionalLight {
    vec4 color;
    vec4 direction;
};

layout (std140) uniform DirectionalLights {
    DirectionalLight dlight[16];
};

uniform vec3 ambient_color;
uniform vec3 camera_position;

uniform sampler2D albedo;
uniform sampler2D emission;
uniform sampler2D normal;
uniform sampler2D metallic;
uniform sampler2D roughness;
uniform sampler2D ambient_occlusion;
uniform sampler2D caveat;

in VertexData {
    vec4 position;
    vec3 normal;
    vec3 tangent;
    vec2 tex_coord;
} vertex;

out vec4 out_color;

const float PI = 3.14159265359;

float normal_distribution(vec3 N, vec3 H, float a) {
    float a2 = a * a;
    float NdotH = max(dot(N, H), 0.0);
    float NdotH2 = NdotH*NdotH;

    float denom = (NdotH2 * (a2 - 1.0) + 1.0);
    denom = PI * denom * denom;

    return (a2 + 0.0000001) / denom;
}

float geometry(float NdotV, float NdotL, float r2) {
    float a1 = r2 + 1.0;
    float k = a1 * a1 / 8.0;
    float denom = NdotV * (1.0 - k) + k;
    float ggx1 = NdotV / denom;
    denom = NdotL * (1.0 - k) + k;
    float ggx2 = NdotL / denom;
    return ggx1 * ggx2;
}

vec3 fresnel(float HdotV, vec3 fresnel_base) {
    return fresnel_base + (1.0 - fresnel_base) * pow(1.0 - HdotV, 5.0);
}

void main() {
    vec3 albedo             = texture(albedo, vertex.tex_coord).rgb;
    vec3 emission           = texture(emission, vertex.tex_coord).rgb;
    vec3 normal             = texture(normal, vertex.tex_coord).rgb;
    float metallic          = texture(metallic, vertex.tex_coord).r;
    float roughness         = texture(roughness, vertex.tex_coord).r;
    float ambient_occlusion = texture(ambient_occlusion, vertex.tex_coord).r;
    float caveat            = texture(caveat, vertex.tex_coord).r; // TODO: Use caveat

    // normal conversion
    normal = normal * 2 - 1;

    float roughness2 = roughness * roughness;
    vec3 fresnel_base = mix(vec3(0.04), albedo, metallic);

    vec3 vertex_normal = normalize(vertex.normal);
    vec3 vertex_tangent = normalize(vertex.tangent - vertex_normal * dot(vertex_normal, vertex.tangent));
    vec3 vertex_bitangent = normalize(cross(vertex_normal, vertex_tangent));
    mat3 vertex_basis = mat3(vertex_tangent, vertex_bitangent, vertex_normal);
    normal = normalize(vertex_basis * normal);


    vec3 lighted = vec3(0.0);
    for (int i = 0; i < point_light_count; i++) {
        vec3 view_direction = normalize(camera_position - vertex.position.xyz);
        vec3 light_direction = normalize(plight[i].position.xyz - vertex.position.xyz);
        float intensity = plight[i].intensity / dot(light_direction, light_direction);

        vec3 halfway = normalize(view_direction + light_direction);
        float normal_distribution = normal_distribution(normal, halfway, roughness2);

        float NdotV = max(dot(normal, view_direction), 0.0);
        float NdotL = max(dot(normal, light_direction), 0.0);
        float HdotV = max(dot(halfway, view_direction), 0.0);
        float geometry = geometry(NdotV, NdotL, roughness2);

        vec3 fresnel = fresnel_base + (1.0 - fresnel_base) * pow(1.0 - HdotV, 5.0);
        vec3 diffuse = vec3(1.0) - fresnel;
        diffuse *= 1.0 - metallic;

        vec3 nominator = normal_distribution * geometry * fresnel;
        float denominator = 4 * NdotV * NdotL + 0.0001;
        vec3 specular = nominator / denominator;

        lighted += (diffuse * albedo / PI + specular) * plight[i].color.rgb * intensity * NdotL;
    }

    vec3 ambient = ambient_color * albedo * ambient_occlusion;
    vec3 color = ambient + lighted + emission;
   
    out_color = vec4(color, 1.0);
}
