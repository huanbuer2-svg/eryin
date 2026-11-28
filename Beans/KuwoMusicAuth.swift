import Combine
import Foundation

/// 酷我音乐登录态：走网页版 Cookie（粘贴登录），并保存 uid / 昵称 / 头像。
final class KuwoMusicAuth: ObservableObject {
    static let shared = KuwoMusicAuth()

    @Published private(set) var isLoggedIn = false
    @Published private(set) var userId = ""
    @Published private(set) var nickname = ""
    @Published private(set) var avatarURL: URL?
    @Published private(set) var cookie = ""

    private let storeKey = "beans.kuwo.auth.v1"
    private let defaults = UserDefaults.standard

    private init() {
        guard let saved = defaults.dictionary(forKey: storeKey) as? [String: String] else { return }
        cookie = saved["cookie"] ?? ""
        userId = saved["uid"] ?? ""
        nickname = saved["nickname"] ?? ""
        avatarURL = saved["avatar"].flatMap { $0.isEmpty ? nil : URL(string: $0) }
        isLoggedIn = !cookie.isEmpty && !userId.isEmpty
    }

    /// 网页版需要的 csrf 头，就是 Cookie 里的 kw_token
    var csrfToken: String {
        for part in cookie.split(separator: ";") {
            let item = part.trimmingCharacters(in: .whitespaces)
            if item.lowercased().hasPrefix("kw_token=") {
                return String(item.dropFirst("kw_token=".count)).trimmingCharacters(in: .whitespaces)
            }
        }
        return ""
    }

    var cookieHeader: String { cookie }

    func save(cookie rawCookie: String, user: KuwoMusicAPI.UserInfo) {
        let normalized = rawCookie.trimmingCharacters(in: .whitespacesAndNewlines)
        cookie = normalized
        userId = user.uid
        nickname = user.nickname
        avatarURL = user.avatarURL
        isLoggedIn = true
        defaults.set(
            [
                "cookie": cookie,
                "uid": userId,
                "nickname": nickname,
                "avatar": avatarURL?.absoluteString ?? "",
            ],
            forKey: storeKey
        )
        BeansLogger.shared.log("酷我音乐登录成功 uid=\(userId) nickname=\(nickname)", level: .info)
    }

    func logout() {
        cookie = ""
        userId = ""
        nickname = ""
        avatarURL = nil
        isLoggedIn = false
        defaults.removeObject(forKey: storeKey)
        BeansLogger.shared.log("酷我音乐已退出登录", level: .info)
    }
}
