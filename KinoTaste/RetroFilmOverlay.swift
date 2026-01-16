//
//  RetroFilmOverlay.swift
//  KinoTaste
//
//  Created by Boxiang Shan on 2026/1/12.
//

import SwiftUI

struct RetroFilmOverlay: View {
    // 🟢 增强参数：让效果更明显
    var vignetteIntensity: Double = 0.8 // 暗角强度 (0.0 - 1.0)
    var grainIntensity: Double = 0.12   // 噪点强度 (建议 0.1 - 0.2 以肉眼可见)
    var tintOpacity: Double = 0.3       // 色偏浓度
    
    var body: some View {
        ZStack {
            // 1. 强力噪点层 (Film Grain)
            // 使用 Canvas 绘制高密度噪点
            GrainView(intensity: grainIntensity)
                .blendMode(.overlay)
                .opacity(0.6) // 提高不透明度
            
            // 2. 复古暖色调 (Color Grade)
            // 模拟 Kodak 胶片的暖黄感
            Color(red: 0.95, green: 0.90, blue: 0.80)
                .blendMode(.multiply) // 正片叠底
                .opacity(tintOpacity)
            
            // 3. 漏光氛围 (Light Leak)
            // 左上角冷光，右下角暖光，增加层次
            LinearGradient(
                colors: [
                    Color.blue.opacity(0.15),
                    Color.clear,
                    Color.orange.opacity(0.1)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .blendMode(.screen)
            
            // 4. 强力暗角 (Vignette)
            // 压暗四周，模拟老镜头
            RadialGradient(
                gradient: Gradient(stops: [
                    .init(color: .clear, location: 0.0), // 中心完全清晰
                    .init(color: .black.opacity(0.1), location: 0.5),
                    .init(color: .black.opacity(vignetteIntensity), location: 1.2) // 边缘深度压暗
                ]),
                center: .center,
                startRadius: 50,
                endRadius: 800
            )
            .allowsHitTesting(false)
        }
        .allowsHitTesting(false) // 关键：点击穿透，不影响操作
        .edgesIgnoringSafeArea(.all)
    }
}

// 噪点绘制组件
private struct GrainView: View {
    let intensity: Double
    
    var body: some View {
        GeometryReader { proxy in
            Canvas { context, size in
                let width = size.width
                let height = size.height
                // 增加噪点密度
                let dotCount = Int(width * height * 0.002)
                
                for _ in 0..<dotCount {
                    let x = Double.random(in: 0...width)
                    let y = Double.random(in: 0...height)
                    let s = Double.random(in: 1...2.5) // 稍微加大噪点尺寸
                    let rect = CGRect(x: x, y: y, width: s, height: s)
                    // 混合黑白噪点
                    let gray = Double.random(in: 0...1)
                    context.fill(Path(rect), with: .color(.init(white: gray, opacity: intensity)))
                }
            }
        }
        .drawingGroup() // 开启 Metal 加速
    }
}
