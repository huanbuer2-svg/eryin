//
//  GlacierTheme.swift
//  贰音 · 冰川蓝紫主题（2.0.3 版）
//
//  只在「冰川蓝紫」配色下启用：
//    · 页面背景：冰蓝 → 薰衣草的冷色渐变 + 两团冷光晕（替换原暖色氛围背景）
//    · 液态玻璃卡片：叠加冰川淡色（见 BeansGlass）
//    · 强调色 / 渐变描边：由 BeansAccent.ice 统一提供
//
//  其他配色不受影响，仍走系统默认氛围背景。
//

import SwiftUI
import UIKit

enum GlacierPalette {
    /// 生成随系统浅色 / 深色自动切换的颜色
    static func dynamic(light: UInt32, dark: UInt32, alpha: CGFloat = 1) -> Color {
        Color(UIColor { trait in
            let hex = trait.userInterfaceStyle == .dark ? dark : light
            return UIColor(
                red: CGFloat((hex >> 16) & 0xFF) / 255,
                green: CGFloat((hex >> 8) & 0xFF) / 255,
                blue: CGFloat(hex & 0xFF) / 255,
                alpha: alpha
            )
        })
    }

    /// 主强调色：冰川蓝
    static let accent       = dynamic(light: 0x5B8CFF, dark: 0x8FB4FF)
    /// 次强调色：薰衣草紫
    static let accentSecond = dynamic(light: 0x8B7CF6, dark: 0xB2A6FF)
    /// 背景顶部 / 底部
    static let bgTop        = dynamic(light: 0xEEF3FF, dark: 0x0E1124)
    static let bgBottom     = dynamic(light: 0xE6E0FF, dark: 0x1A1538)
    /// 玻璃描边高光
    static let glassStroke   = dynamic(light: 0xFFFFFF, dark: 0xFFFFFF, alpha: 0.45)

    /// 品牌渐变（按钮、进度条、选中态）
    static let brandGradient = LinearGradient(
        colors: [accent, accentSecond],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

/// 冰川背景：冷色渐变 + 上下两团柔光，替代默认暖色氛围背景
struct GlacierBackdrop: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.beansSettingsPerformanceMode) private var settingsPerformanceMode

    private var glowOpacity: Double {
        colorScheme == .dark ? 0.45 : 0.38
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [GlacierPalette.bgTop, GlacierPalette.bgBottom],
                startPoint: .top,
                endPoint: .bottom
            )
            if !settingsPerformanceMode {
                Circle()
                    .fill(GlacierPalette.accent.opacity(glowOpacity))
                    .frame(width: 340, height: 340)
                    .blur(radius: 100)
                    .offset(x: 150, y: -300)
                Circle()
                    .fill(GlacierPalette.accentSecond.opacity(glowOpacity * 0.9))
                    .frame(width: 320, height: 320)
                    .blur(radius: 110)
                    .offset(x: -160, y: 340)
            }
        }
        .ignoresSafeArea()
    }
}
