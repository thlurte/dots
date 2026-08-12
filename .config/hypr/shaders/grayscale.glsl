#version 300 es
precision mediump float;

in vec2 v_texcoord;
out vec4 fragColor;
uniform sampler2D tex;

void main() {
    vec4 pixColor = texture(tex, v_texcoord);
    
    // 1. Get the pure grayscale value
    float gray = dot(pixColor.rgb, vec3(0.299, 0.587, 0.114));
    
    // 2. Tint it warm (Boost red, lower blue). min() prevents clipping to pure white.
float r = min(gray * 1.3, 1.0);  // Push red higher
    float g = min(gray * 0.8, 1.0);  
    float b = min(gray * 0.3, 1.0);  // 70% reduction in blue
    fragColor = vec4(r, g, b, pixColor.a);
}
