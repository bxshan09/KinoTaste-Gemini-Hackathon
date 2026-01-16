//
//  Theme.swift
//  KinoTaste
//
//  Created by Boxiang Shan on 2026/1/15.
//

import SwiftUI

// MARK: - 核心字体修复逻辑
struct RetroFontModifier: ViewModifier {
    let size: CGFloat
    let isBold: Bool
    
    func body(content: Content) -> some View {
        content
            .font(.custom(isBold ? "Courier-Bold" : "Courier", size: size))
            // 🟢 核心修复 1: 负基线偏移 (关键！)
            // 将文字整体“下沉”，让原本被切掉的中文顶部（Ascender）露出来
            // 0.2 的系数是经过测试最适合 Courier + PingFang 的比例
            .baselineOffset(-size * 0.2)
            
            // 🟢 核心修复 2: 底部补偿
            // 因为文字下沉了，需要增加底部内边距，防止文字被切底或与下方元素重叠
            .padding(.bottom, size * 0.1)
            
            // 🟢 视觉优化: 增加一点字间距，让中文排版更有呼吸感
            .tracking(0.5)
            
            // 🟢 布局安全: 强制内容不被压缩，确保 ScrollView 内能完整显示
            .fixedSize(horizontal: false, vertical: true)
    }
}

// MARK: - 便捷调用扩展
extension View {
    /// 应用复古字体 (已修复中文切顶问题)
    /// - Parameters:
    ///   - size: 字号
    ///   - bold: 是否加粗 (默认 false)
    func retroFont(size: CGFloat, bold: Bool = false) -> some View {
        self.modifier(RetroFontModifier(size: size, isBold: bold))
    }
}
