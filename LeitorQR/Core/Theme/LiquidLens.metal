#include <metal_stdlib>
#include <SwiftUI/SwiftUI_Metal.h>

using namespace metal;

/// 2D 晶体水滴凸透镜折射算法（Liquid Lens Refraction Shader）
/// 用于 iOS 17/18 SwiftUI .distortionEffect 降级支持
///
/// position: 当前像素绝对坐标
/// center: 水滴中心绝对坐标
/// radius: 水滴影响半径
/// strength: 折射畸变强度
[[ stitchable ]] float2 liquidRefraction(float2 position, float2 center, float radius, float strength) {
    float2 delta = position - center;
    float dist = length(delta);
    
    // 超出水滴边缘或处于极中心点时不发生折射
    if (dist < 0.5 || dist > radius) {
        return position;
    }
    
    // 归一化距离 [0.0, 1.0]
    float norm = dist / radius;
    
    // 模拟真实水滴凸透镜光学折射特性：
    // 在 0.3 ~ 0.88 边缘表面张力区域产生最强折射，贴近外沿平滑归零
    float rimWeight = smoothstep(0.3, 0.88, norm) * (1.0 - smoothstep(0.88, 1.0, norm));
    
    // 凸透镜拉伸偏移向量
    float displacement = strength * rimWeight * (1.0 - norm * 0.4);
    
    return position - (delta / dist) * displacement;
}
