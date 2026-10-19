#include <metal_stdlib>
using namespace metal;

namespace {
constant float2 vertices[] = {
    {0, -1}, {0.247487373, -0.247487373},
    {1, 0}, {0.247487373, 0.247487373},
    {0, 1}, {-0.247487373, 0.247487373},
    {-1, 0}, {-0.247487373, -0.247487373}
};

// Intersections of adjacent unit edge normals preserve Canvas's miter joins
// and point-sized strokes, independently of the animated particle radius.
constant float2 miters[] = {
    {0, -3.200829620}, {0.792164915, -0.792164915},
    {3.200829620, 0}, {0.792164915, 0.792164915},
    {0, 3.200829620}, {-0.792164915, 0.792164915},
    {-3.200829620, 0}, {-0.792164915, -0.792164915}
};

float starDistance(float2 point, float radius, float offset = 0) {
    float distanceSquared = INFINITY;
    bool inside = false;
    for (int i = 0; i < 8; ++i) {
        float2 a = vertices[i] * radius + miters[i] * offset;
        float2 b = vertices[(i + 1) % 8] * radius + miters[(i + 1) % 8] * offset;
        float2 edge = b - a;
        float2 delta = point - a;
        float projection = clamp(dot(delta, edge) / max(dot(edge, edge), 1e-10f), 0.0f, 1.0f);
        float2 nearest = delta - edge * projection;
        distanceSquared = min(distanceSquared, dot(nearest, nearest));
        if ((a.y > point.y) != (b.y > point.y)
            && point.x < (b.x - a.x) * (point.y - a.y) / (b.y - a.y) + a.x) {
            inside = !inside;
        }
    }
    return sqrt(distanceSquared) * (inside ? -1.0f : 1.0f);
}

float coverage(float distance) {
    return saturate(0.5f - distance / max(fwidth(distance), 0.001f));
}

void over(thread half4 &destination, half4 color, float opacity) {
    half4 source = color * half(opacity);
    destination = source + destination * (1 - source.a);
}
}

[[ stitchable ]] half4 combatStunStars(
    float2 position,
    device const float *particles, int floatCount,
    half4 primary, half4 secondary, half4 ink, half4 paper
) {
    half4 result = 0;
    // Records retain the original back-to-front sort and five paint operations.
    for (int i = 0; i + 4 < floatCount; i += 5) {
        float2 delta = position - float2(particles[i], particles[i + 1]);
        float radius = abs(particles[i + 2]);
        float opacity = particles[i + 4];
        if (radius < 0.001f || opacity <= 0 || max(abs(delta.x), abs(delta.y)) > radius + 4) {
            continue;
        }
        float angle = particles[i + 3];
        float c = cos(angle), s = sin(angle);
        float2 local = float2(c * delta.x + s * delta.y, -s * delta.x + c * delta.y);
        float2 shadowDelta = delta - float2(0, 1.2f);
        float2 shadow = float2(c * shadowDelta.x + s * shadowDelta.y, -s * shadowDelta.x + c * shadowDelta.y);
        float body = coverage(starDistance(local, radius));
        float outline = coverage(starDistance(local, radius, 0.6f))
            * (1 - coverage(starDistance(local, radius, -0.6f)));
        float rim = coverage(starDistance(local, radius, 0.3f))
            * (1 - coverage(starDistance(local, radius, -0.3f)));
        over(result, ink, coverage(starDistance(shadow, radius)) * 0.45f * opacity);
        over(result, ink, outline * 0.65f * opacity);
        over(result, primary, body * opacity);
        over(result, secondary, rim * 0.8f * opacity);
        over(result, paper, coverage(starDistance(local, radius * 0.44f)) * 0.92f * opacity);
    }
    return result;
}
