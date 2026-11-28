//
//  CiliCiliKitStub.swift
//  贰音 · iOS 15 兼容构建用的 CiliCiliKit 替身
//
//  背景：官方 2.0.3 源码里的 CiliCili（哔哩哔哩）模块大量使用 iOS 16/17/18/26 API
//  （152 个文件、777 处），无法降到 iOS 15。要出 iOS 15 包只能把这个模块摘掉。
//  本文件提供 App 端桥接代码所需的同名 API，行为为空实现：哔哩哔哩相关界面显示占位提示，
//  音乐相关功能完全不受影响。
//

import Combine
import SwiftUI
import UIKit

// MARK: - 入口 / 外观

public final class CiliCiliHostAppDelegate: UIResponder, UIApplicationDelegate {
    public override init() {
        super.init()
    }
}

public final class CiliCiliHostAppearance {
    public static let shared = CiliCiliHostAppearance()
    private init() {}

    public func update(backdrop: AnyView?, accent: Color, usesLiquidGlass: Bool) {
        // 无哔哩哔哩界面，无需同步外观
    }
}

// MARK: - 路由

public enum CiliCiliRoute: Hashable {
    case video(bvid: String, title: String, cover: String?, cid: Int?)
    case uploader(mid: Int, name: String, avatar: String?)
    case live(roomID: Int)
    case collection(id: Int, isSeries: Bool, ownerID: Int, ownerName: String, title: String)
    case account
}

public struct CiliCiliRouteHost: View {
    let route: CiliCiliRoute

    public init(route: CiliCiliRoute) {
        self.route = route
    }

    public var body: some View {
        CiliCiliUnavailableView()
    }
}

public struct CiliCiliHomeView: View {
    let platforms: [String]
    let selectPlatform: (String) -> Void

    public init(platforms: [String], selectPlatform: @escaping (String) -> Void) {
        self.platforms = platforms
        self.selectPlatform = selectPlatform
    }

    public var body: some View {
        CiliCiliUnavailableView()
    }
}

public struct CiliCiliAudioCommentsHost: View {
    let bvid: String

    public init(bvid: String) {
        self.bvid = bvid
    }

    public var body: some View {
        CiliCiliUnavailableView()
    }
}

/// 占位提示：本构建不带哔哩哔哩模块
private struct CiliCiliUnavailableView: View {
    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "play.slash")
                .font(.system(size: 34, weight: .light))
                .foregroundStyle(.secondary)
            Text("当前版本不含哔哩哔哩模块")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.secondary)
            Text("iOS 15 兼容版只保留音乐功能")
                .font(.system(size: 12))
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - 播放监听

public struct CiliCiliListenQueueItem: Hashable {
    public var bvid: String
    public var cid: Int?
    public var aid: Int?
    public var title: String
    public var artist: String
    public var coverURL: String?
    public var duration: TimeInterval

    public init(
        bvid: String = "",
        cid: Int? = nil,
        aid: Int? = nil,
        title: String = "",
        artist: String = "",
        coverURL: String? = nil,
        duration: TimeInterval = 0
    ) {
        self.bvid = bvid
        self.cid = cid
        self.aid = aid
        self.title = title
        self.artist = artist
        self.coverURL = coverURL
        self.duration = duration
    }
}

public struct CiliCiliVideoListenRequest {
    public var bvid: String
    public var cid: Int?
    public var aid: Int?
    public var title: String
    public var artist: String
    public var coverURL: String?
    public var duration: TimeInterval
    public var ownerID: Int?
    public var preservesQueueOrder: Bool
    public var queue: [CiliCiliListenQueueItem]

    public init(
        bvid: String = "",
        cid: Int? = nil,
        aid: Int? = nil,
        title: String = "",
        artist: String = "",
        coverURL: String? = nil,
        duration: TimeInterval = 0,
        ownerID: Int? = nil,
        preservesQueueOrder: Bool = false,
        queue: [CiliCiliListenQueueItem] = []
    ) {
        self.bvid = bvid
        self.cid = cid
        self.aid = aid
        self.title = title
        self.artist = artist
        self.coverURL = coverURL
        self.duration = duration
        self.ownerID = ownerID
        self.preservesQueueOrder = preservesQueueOrder
        self.queue = queue
    }
}

public struct CiliCiliListenPlaybackSnapshot {
    public var time: TimeInterval
    public var isPlaying: Bool

    public init(time: TimeInterval, isPlaying: Bool) {
        self.time = time
        self.isPlaying = isPlaying
    }
}

public final class CiliCiliRuntime: ObservableObject {
    public static let shared = CiliCiliRuntime()
    /// 本构建没有哔哩哔哩播放，恒为 false（App 侧用它避免误伤音乐播放）
    public static var hasActivePlayback = false {
        didSet { hasActivePlayback = false }
    }

    @Published public var isVideoDetailActive = false
    @Published public var isLiveRoomActive = false

    public var onPlaybackActivation: (() -> Void)?
    public var onVideoListenModeChange: ((CiliCiliVideoListenRequest, Bool, TimeInterval, Bool) -> Void)?
    public var onVideoListenPlaybackSnapshot: ((CiliCiliVideoListenRequest) -> CiliCiliListenPlaybackSnapshot?)?
    public var onVideoListenQueueChange: ((CiliCiliVideoListenRequest) -> Void)?
    public var onSessionChange: ((String, String, String, String?) -> Void)?

    private init() {}

    public func stopPlaybackForMusic() {}

    public func synchronizeLegacySession(cookie: String, name: String, userID: String, avatar: String?) {}
}

// MARK: - 错误

public struct BilibiliError: LocalizedError {
    public let message: String

    public init(message: String) {
        self.message = message
    }

    public var errorDescription: String? { message }
}
