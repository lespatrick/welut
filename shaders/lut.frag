#version 460 core

#include <flutter/runtime_effect.glsl>

uniform vec2 uSize;
uniform float uLutLevel;
uniform float uLutWidth;
uniform sampler2D uImage;
uniform sampler2D uLut;

out vec4 fragColor;

void main() {
    vec2 uv = FlutterFragCoord().xy / uSize;
    vec4 color = texture(uImage, uv);
    
    float r = clamp(color.r, 0.0, 1.0);
    float g = clamp(color.g, 0.0, 1.0);
    float b = clamp(color.b, 0.0, 1.0);
    
    float n = uLutLevel;
    float n2 = n * n;
    
    float rNorm = r * (n - 1.0);
    float gNorm = g * (n - 1.0);
    float bNorm = b * (n - 1.0);
    
    float r0 = floor(rNorm);
    float g0 = floor(gNorm);
    float b0 = floor(bNorm);
    
    float lutIndex = r0 + g0 * n + b0 * n2;
    
    float lutY = floor(lutIndex / uLutWidth);
    float lutX = mod(lutIndex, uLutWidth);
    
    vec2 lutUv = (vec2(lutX, lutY) + 0.5) / vec2(uLutWidth, (n2 * n) / uLutWidth);
    vec4 lutColor = texture(uLut, lutUv);
    
    fragColor = vec4(lutColor.rgb, color.a);
}
