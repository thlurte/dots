#version 440

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float yaw;
    float pitch;
    float sphereRadius;
    float haloStrength;
    float nightLevel;
    float rainMix;
    float oceanMix;
    vec4 haloColor;
    float rainPhase;
};

layout(binding = 1) uniform sampler2D earthTex;
layout(binding = 2) uniform sampler2D rainTex;
layout(binding = 3) uniform sampler2D oceanTex;

const float PI = 3.14159265359;

// Large-scale zonal wind by latitude: tropical easterlies, mid-latitude
// westerlies peaking near 45, polar easterlies. Positive = eastward.
// The cos(lat) taper keeps polar rows from racing as meridians converge.
float zonalWind(float lat) {
    return -cos(4.0 * lat) * cos(lat);
}

void main() {
    vec2 sp = qt_TexCoord0 * 2.0 - 1.0;
    sp.y = -sp.y;

    float r = length(sp);
    float R = max(sphereRadius, 0.05);
    float aa = max(fwidth(r), 0.0008);

    // Sphere coverage with antialiased limb
    float sphereA = 1.0 - smoothstep(R - aa, R + aa, r);

    // Atmosphere — tight falloff so it dies before the item edge (no square clip)
    float outside = max(r - R, 0.0);
    float haloA = exp(-outside * 28.0) * haloStrength;
    // Hard cut once glow is past ~10% of radius past the limb
    haloA *= 1.0 - smoothstep(0.06, 0.11, outside);

    // Point on the unit sphere facing the viewer (+z toward camera)
    vec2 d = sp / R;
    float dl = length(d);
    if (dl > 1.0) {
        d /= dl;
    }
    vec3 n = vec3(d, sqrt(max(0.0, 1.0 - dot(d, d))));

    // Undo pitch (X axis), then yaw (Y axis) to reach sphere-local coords
    float cp = cos(pitch);
    float sinp = sin(pitch);
    vec3 a = vec3(n.x, n.y * cp + n.z * sinp, -n.y * sinp + n.z * cp);

    float cy = cos(yaw);
    float sy = sin(yaw);
    vec3 l = vec3(a.x * cy - a.z * sy, a.y, a.x * sy + a.z * cy);

    float lat = asin(clamp(l.y, -1.0, 1.0));
    float lon = atan(l.z, l.x);
    // Equirectangular: west on the left (u increases eastward). Qt samples
    // with +X to the right, so lon must be mirrored vs camera-space X.
    vec2 uv = vec2(0.5 - lon / (2.0 * PI), 0.5 - lat / PI);

    vec3 albedo = texture(earthTex, uv).rgb;

    if (oceanMix > 0.01) {
        vec4 ocean = texture(oceanTex, uv);
        albedo = mix(albedo, ocean.rgb, clamp(ocean.a * oceanMix, 0.0, 1.0));
    }
    if (rainMix > 0.01) {
        // Drift the precipitation field along the prevailing wind. u increases
        // westward here (uv is mirrored), so an eastward wind lowers uv.x and
        // the sample offset is +u.
        vec2 drift = vec2(zonalWind(lat) * 0.03, 0.0);
        // Two half-cycle-offset samples cross-dissolved: motion stays smooth
        // and seamless at the loop point while displacement stays bounded.
        float p0 = fract(rainPhase);
        float p1 = fract(rainPhase + 0.5);
        vec4 rain = mix(texture(rainTex, uv + drift * p0),
                        texture(rainTex, uv + drift * p1),
                        abs(1.0 - 2.0 * p0));
        float wet = clamp(rain.a * rainMix, 0.0, 1.0);
        albedo = mix(albedo, albedo * 0.52 + rain.rgb * 1.12, wet);
    }

    // Soft directional light so the sphere reads as a ball
    vec3 L = normalize(vec3(-0.42, 0.34, 0.84));
    float diff = max(dot(n, L), 0.0);
    float shade = nightLevel + (1.0 - nightLevel) * pow(diff, 0.8);

    vec3 col = albedo * shade;

    // Subtle rim only — keep soft so it doesn't read as a clipped square
    float fres = pow(1.0 - n.z, 3.5);
    col += haloColor.rgb * fres * 0.22;

    vec3 premult = col * sphereA + haloColor.rgb * haloA * (1.0 - sphereA);
    float alpha = sphereA + haloA * (1.0 - sphereA);

    fragColor = vec4(premult, alpha) * qt_Opacity;
}
