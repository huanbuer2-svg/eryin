//
//  IOS15CompatStubs.swift
//  贰音 · iOS 15 兼容构建：把依赖 iOS 16+ / 26 API 的整块功能替换成占位实现。
//
//  被替换的三个文件（已在 project.yml 的 sources.excludes 中排除）：
//    · Beans/Folia/**                —— 新播放页（依赖 iOS 16 的 Layout 协议）
//    · Beans/NowPlayingLiveActivity.swift —— 灵动岛/锁屏实时活动（ActivityKit，iOS 16.1）
//    · Beans/LockScreenArtwork.swift —— 锁屏动态封面（MediaPlayer iOS 26 API）
//

import SwiftUI

/// 标记：iOS 15 兼容构建（Folia 播放页等 iOS 16+ 功能在此构建中不可用）
let BeansIOS15Build = true

// MARK: - iOS 15 兼容修饰器

extension View {
    /// iOS 16 才有 scrollContentBackground，低版本直接忽略
    @ViewBuilder
    func beansScrollContentHidden() -> some View {
        if #available(iOS 16.0, *) {
            self.scrollContentBackground(.hidden)
        } else {
            self
        }
    }
}

// MARK: - Folia 播放页

struct FoliaStageView: View {
    let song: Song?
    let lyrics: [LyricLine]
    let onBack: () -> Void
    let onSettings: () -> Void

    var body: some View {
        EmptyView()
    }
}

// MARK: - 实时活动

@MainActor
final class BeansNowPlayingLiveActivity {
    static let shared = BeansNowPlayingLiveActivity()

    private init() {}

    func update(song: Song?, isPlaying: Bool) {}
}

// MARK: - 锁屏动态封面

final class BeansLockScreenArtwork {
    /// 与设置页共用同一个开关 key
    static let enabledKey = "beans.lockScreenImmersiveArtwork.enabled"

    /// 动态封面就绪回调；iOS 15 无动态封面，永远不会触发
    var onReady: (() -> Void)?

    init() {}

    /// iOS 15 的 MediaPlayer 不支持动态封面，直接返回空
    func artwork(sourceURL: URL) -> [String: Any] {
        [:]
    }
}
