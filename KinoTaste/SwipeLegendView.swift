//
//  SwipeLegendView.swift
//  KinoTaste
//
//  Created by Boxiang Shan on 2026/1/12.
//

import SwiftUI

struct SwipeLegendView: View {
    // 闭包回调：0=看过(左), 1=不想看(上), 2=想看(右)
    var onAction: ((Int) -> Void)? = nil
    
    private let impact = UIImpactFeedbackGenerator(style: .light)
    private let mutedYellow = Color(red: 0.92, green: 0.85, blue: 0.55)
    
    var body: some View {
        HStack(spacing: 40) {
            // 1. 左滑：看过
            LegendButton(
                icon: "arrow.left",
                label: "看过",
                iconColor: .blue.opacity(0.8),
                borderColor: mutedYellow,
                action: { trigger(0) }
            )
            
            // 2. 上滑：不想看
            LegendButton(
                icon: "arrow.up",
                label: "不想看",
                iconColor: .gray.opacity(0.8),
                borderColor: mutedYellow,
                isSmall: true,
                action: { trigger(1) }
            )
            
            // 3. 右滑：想看
            LegendButton(
                icon: "arrow.right",
                label: "想看",
                iconColor: Color(red: 0.8, green: 0.2, blue: 0.2),
                borderColor: mutedYellow,
                action: { trigger(2) }
            )
        }
        .padding(.vertical, 10)
    }
    
    private func trigger(_ direction: Int) {
        impact.impactOccurred()
        onAction?(direction)
    }
}

struct LegendButton: View {
    let icon: String
    let label: String
    let iconColor: Color
    let borderColor: Color
    var isSmall: Bool = false
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                // 圆形按钮背景
                ZStack {
                    Circle()
                        .fill(Color(UIColor.systemBackground))
                        .shadow(color: .black.opacity(0.15), radius: 6, y: 4)
                    
                    Image(systemName: icon)
                        .font(.system(size: isSmall ? 22 : 26, weight: .black))
                        .foregroundColor(iconColor)
                }
                .frame(width: isSmall ? 54 : 64, height: isSmall ? 54 : 64)
                .overlay(
                    Circle().stroke(borderColor, lineWidth: 3)
                )
                
                // 文字标签 (修复字体和遮挡)
                Text(LocalizedStringKey(label))
                    .retroFont(size: 12, bold: true) // ✅ 修复：底部标签不再切底
                    .foregroundColor(.secondary)
                    .fixedSize() // 防止文字换行
            }
        }
        .buttonStyle(LegendScaleButtonStyle())
    }
}

private struct LegendScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.9 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}
