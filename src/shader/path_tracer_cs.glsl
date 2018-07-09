// ------------------------------------------------------------------
// INPUTS -----------------------------------------------------------
// ------------------------------------------------------------------

layout (local_size_x = 1, local_size_y = 1) in;
layout (binding = 0, rgba32f) readonly uniform image2D I_Input;
layout (binding = 1, rgba32f) writeonly uniform image2D I_Output;

// ------------------------------------------------------------------
// UNIFORMS ---------------------------------------------------------
// ------------------------------------------------------------------

uniform int u_NumFrames;
uniform float u_FOV;
uniform float u_AspectRatio;
uniform vec2 u_Resolution;
uniform mat4 u_InvViewMat;
uniform mat4 u_InvProjectionMat;

// ------------------------------------------------------------------
// CONSTANTS --------------------------------------------------------
// ------------------------------------------------------------------

const float kPI = 3.14159265359;

// ------------------------------------------------------------------
// STRUCTURES -------------------------------------------------------
// ------------------------------------------------------------------

struct Ray
{
    vec3 direction;
    vec3 origin;
};

struct HitRecord
{
    float t;
    vec3 position;
    vec3 normal;
    vec3 color;
};

struct Sphere
{
    float radius;
    vec3 position;
    vec3 diffuse;
};

struct Scene
{   
    int num_spheres;
    Sphere spheres[32];
};

// ------------------------------------------------------------------
// FUNCTIONS --------------------------------------------------------
// ------------------------------------------------------------------

uint rand(inout uint state)
{
    uint x = state;
    x ^= x << 13;
    x ^= x >> 17;
    x ^= x << 15;
    state = x;
    return x;
}

// ------------------------------------------------------------------

float random_float_01(inout uint state)
{
    return (rand(state) & 0xFFFFFF) / 16777216.0f;
}

// ------------------------------------------------------------------

vec3 random_in_unit_disk(inout uint state)
{
    float a = random_float_01(state) * 2.0f * 3.1415926f;
    vec2 xy = vec2(cos(a), sin(a));
    xy *= sqrt(random_float_01(state));
    return vec3(xy, 0);
}

// ------------------------------------------------------------------

vec3 random_in_unit_sphere(inout uint state)
{
    float z = random_float_01(state) * 2.0f - 1.0f;
    float t = random_float_01(state) * 2.0f * 3.1415926f;
    float r = sqrt(max(0.0, 1.0f - z * z));
    float x = r * cos(t);
    float y = r * sin(t);
    vec3 res = vec3(x, y, z);
    res *= pow(random_float_01(state), 1.0 / 3.0);
    return res;
}

// ------------------------------------------------------------------

vec3 random_unit_vector(inout uint state)
{
    float z = random_float_01(state) * 2.0f - 1.0f;
    float a = random_float_01(state) * 2.0f * 3.1415926f;
    float r = sqrt(1.0f - z * z);
    float x = r * cos(a);
    float y = r * sin(a);
    return vec3(x, y, z);
}

// ------------------------------------------------------------------

Ray compute_ray(float x, float y)
{
    x = x * 2.0 - 1.0;
    y = y * 2.0 - 1.0;

    vec4 clip_pos = vec4(x, y, -1.0, 1.0);
    vec4 view_pos = u_InvProjectionMat * clip_pos;

    vec3 dir = vec3(u_InvViewMat * vec4(view_pos.x, view_pos.y, -1.0, 0.0));
    dir = normalize(dir);

    vec4 origin = u_InvViewMat * vec4(0.0, 0.0, 0.0, 1.0);
    origin.xyz /= origin.w;

    Ray r;

    r.origin = origin.xyz;
    r.direction = dir;

    return r;
}

Ray create_ray(in vec3 origin, in vec3 dir)
{
    Ray r;

    r.origin = origin;
    r.direction = dir;

    return r;
}

// ------------------------------------------------------------------

bool ray_sphere_hit(in float t_min, in float t_max, in Ray r, in Sphere s, out HitRecord hit)
{
    vec3 oc = r.origin - s.position;
    float a = dot(r.direction, r.direction);
    float b = dot(oc, r.direction);
    float c = dot(oc, oc) - s.radius * s.radius;
    float discriminant = b * b - a * c;

    if (discriminant > 0.0)
    {
        float temp = (-b - sqrt(b * b - a * c)) / a;

        if (temp < t_max && temp > t_min)
        {
            hit.t = temp;
            hit.position = r.origin + r.direction * hit.t;
            hit.normal = normalize(hit.position - s.position);
            hit.color = s.diffuse;

            return true;
        }

        temp = (-b + sqrt(b * b - a * c)) / a;

        if (temp < t_max && temp > t_min)
        {
            hit.t = temp;
            hit.position = r.origin + r.direction * hit.t;
            hit.normal = normalize(hit.position - s.position);
            hit.color = s.diffuse;

            return true;
        }
    }

    return false;
}

bool ray_scene_hit(in float t_min, in float t_max, in Ray ray, in Scene scene, out HitRecord rec)
{
    float closest = t_max;
    bool hit_anything = false;

    for (int i = 0; i < scene.num_spheres; i++)
    {
        if (ray_sphere_hit(t_min, closest, ray, scene.spheres[i], rec))
        {
            hit_anything = true;
            closest = rec.t;
        }
    }

    return hit_anything;
}

uint state = 34;

bool trace_once(in Ray ray, in Scene scene, out HitRecord rec, out vec3 color)
{
    if (ray_scene_hit(0.001, 100000.0, ray, scene, rec))
    {
        color = rec.color;
        return true;
    }
    else
    {
        float t = 0.5 * (ray.direction.y + 1.0);
        color = (1.0 - t) * vec3(1.0) + t * vec3(0.5, 0.7, 1.0);
        return false;
    }
}

vec3 trace(in Ray ray, in Scene scene)
{
    vec3 color;
    vec3 result = vec3(0.0);
    HitRecord rec;
    vec3 new_dir;

    Ray new_ray = ray;
    float attenuation = 1.0;

    while (trace_once(new_ray, scene, rec, color))
    {
        new_dir = rec.position + rec.normal + random_in_unit_sphere(state);
        new_ray = create_ray(rec.position, normalize(new_dir - rec.position));

        attenuation *= 0.5;
    }

    result += (attenuation * color);

    return result;
}

// ------------------------------------------------------------------
// MAIN -------------------------------------------------------------
// ------------------------------------------------------------------

void main()
{
    ivec2 pixel_coords = ivec2(gl_GlobalInvocationID.xy);
    vec2 tex_coord = vec2(pixel_coords) / u_Resolution;

    state = gl_GlobalInvocationID.x * 1973 + gl_GlobalInvocationID.y * 9277 + uint(u_NumFrames) * 2699 | 1;

    Ray ray = compute_ray(tex_coord.x, tex_coord.y);

    Scene scene;

    scene.num_spheres = 2;

    scene.spheres[0].radius = 10.0;
    scene.spheres[0].position = vec3(0.0, 0.0, 0.0);
    scene.spheres[0].diffuse = vec3(0.5, 0.5, 0.5);

    scene.spheres[1].radius = 1000.0;
    scene.spheres[1].position = vec3(0.0, -1010.0, 0.0);
    scene.spheres[1].diffuse = vec3(1.0, 1.0, 1.0);

    vec3 color = trace(ray, scene);
    vec3 prev_color = imageLoad(I_Input, pixel_coords).rgb;

    vec3 final = mix(color, prev_color, 0.0);

    imageStore(I_Output, pixel_coords, vec4(final, 1.0));
}

// ------------------------------------------------------------------