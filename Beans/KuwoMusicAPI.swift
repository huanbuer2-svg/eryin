import Foundation

/// 酷我音乐账号接口（网页版 Cookie + csrf 头）。
/// 说明：酷我网页接口没有公开文档，这里按网页版实际请求实现，并把每次请求/解析结果写进日志，
/// 方便拿到真机日志后校正字段。
final class KuwoMusicAPI {
    static let shared = KuwoMusicAPI()

    struct UserInfo {
        let uid: String
        let nickname: String
        let avatarURL: URL?
    }

    private let session: URLSession
    private let webUA = "Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Mobile/15E148 Safari/604.1"

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15
        config.timeoutIntervalForResource = 25
        session = URLSession(configuration: config)
    }

    // MARK: - 用户信息

    func userInfo(cookie: String? = nil) async throws -> UserInfo {
        let data = try await webJSON("https://www.kuwo.cn/api/user/info?httpsStatus=1", api: "user/info", cookie: cookie)
        let payload = (data["data"] as? [String: Any]) ?? data
        let info = (payload["userInfo"] as? [String: Any]) ?? (payload["user"] as? [String: Any]) ?? payload
        let uid = Self.text(info["uid"] ?? info["id"] ?? info["userId"])
        guard let uid, !uid.isEmpty else {
            throw KuwoError(message: "没有取到酷我账号信息，Cookie 可能已失效")
        }
        let nickname = Self.text(info["nickname"] ?? info["name"] ?? info["uname"]) ?? ""
        let avatar = Self.text(info["pic"] ?? info["avatar"] ?? info["headImg"]) ?? ""
        let url = avatar.hasPrefix("http") ? URL(string: avatar) : URL(string: "https://img1.kuwo.cn/star/userhead/\(avatar)")
        return UserInfo(uid: uid, nickname: nickname, avatarURL: url)
    }

    // MARK: - 用户歌单

    func userPlaylists(uid: String) async throws -> [Playlist] {
        var result: [Playlist] = []
        var seen = Set<Int>()
        for page in 1...5 {
            let url = "https://www.kuwo.cn/api/www/user/playlist?uid=\(uid)&pn=\(page)&rn=50&httpsStatus=1"
            let data = try await webJSON(url, api: "user/playlist p\(page)")
            let container = (data["data"] as? [String: Any]) ?? data
            let list = (container["data"] as? [[String: Any]])
                ?? (container["flat"] as? [[String: Any]])
                ?? (container["playlist"] as? [[String: Any]])
                ?? []
            if list.isEmpty { break }
            for item in list {
                guard let id = Self.int(item["id"] ?? item["playlistid"]), id > 0,
                      seen.insert(id).inserted else { continue }
                result.append(
                    Playlist(
                        id: id,
                        name: Self.text(item["name"] ?? item["title"]) ?? "酷我歌单",
                        coverURL: Self.text(item["img"] ?? item["pic"]).flatMap(URL.init(string:)),
                        trackCount: Self.int(item["total"] ?? item["count"] ?? item["songnum"]) ?? 0,
                        playCount: Self.int(item["listencnt"] ?? item["playcnt"]) ?? 0,
                        creatorName: Self.text(item["uname"] ?? item["nickname"]) ?? "",
                        source: .kuwo
                    )
                )
            }
            if list.count < 50 { break }
        }
        BeansLogger.shared.log("酷我歌单列表 count=\(result.count)", level: result.isEmpty ? .warn : .info)
        return result
    }

    // MARK: - 请求

    private func webJSON(_ urlString: String, api: String, cookie: String? = nil) async throws -> [String: Any] {
        guard let url = URL(string: urlString) else { throw KuwoError(message: "地址无效") }
        let override = cookie?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let cookieValue = override.isEmpty ? KuwoMusicAuth.shared.cookieHeader : override
        let csrf = Self.csrfToken(in: cookieValue)
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(cookieValue, forHTTPHeaderField: "Cookie")
        if !csrf.isEmpty {
            request.setValue(csrf, forHTTPHeaderField: "csrf")
        }
        request.setValue("https://www.kuwo.cn/", forHTTPHeaderField: "Referer")
        request.setValue(webUA, forHTTPHeaderField: "User-Agent")
        request.setValue("https://www.kuwo.cn/", forHTTPHeaderField: "Origin")
        request.setValue("application/json, text/plain, */*", forHTTPHeaderField: "Accept")

        let started = Date()
        let (data, response) = try await session.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        let elapsed = String(format: "%.2f", Date().timeIntervalSince(started))
        guard status == 200 else {
            BeansLogger.shared.log("酷我 \(api) 非 200 status=\(status) elapsed=\(elapsed) body=\(String(data: data.prefix(200), encoding: .utf8) ?? "")", level: .warn)
            throw KuwoError(message: "酷我接口返回 \(status)")
        }
        guard let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else {
            BeansLogger.shared.log("酷我 \(api) 解析失败 elapsed=\(elapsed) body=\(String(data: data.prefix(200), encoding: .utf8) ?? "")", level: .warn)
            throw KuwoError(message: "酷我接口返回格式异常")
        }
        BeansLogger.shared.log("酷我 \(api) 完成 elapsed=\(elapsed) bytes=\(data.count)", level: .debug)
        let code = Self.int(json["code"]) ?? 200
        guard code == 200 else {
            let msg = Self.text(json["msg"] ?? json["message"]) ?? "code \(code)"
            BeansLogger.shared.log("酷我 \(api) 业务失败 code=\(code) msg=\(msg)", level: .warn)
            throw KuwoError(message: msg)
        }
        return json
    }

    // MARK: - 字段工具

    static func csrfToken(in cookie: String) -> String {
        for part in cookie.split(separator: ";") {
            let item = part.trimmingCharacters(in: .whitespaces)
            if item.lowercased().hasPrefix("kw_token=") {
                return String(item.dropFirst("kw_token=".count)).trimmingCharacters(in: .whitespaces)
            }
        }
        return ""
    }

    private static func text(_ value: Any?) -> String? {
        if let s = value as? String, !s.isEmpty { return s }
        if let n = value as? Int { return String(n) }
        if let n = value as? Double { return String(Int(n)) }
        return nil
    }

    private static func int(_ value: Any?) -> Int? {
        if let n = value as? Int { return n }
        if let n = value as? Double { return Int(n) }
        if let s = value as? String { return Int(s) }
        return nil
    }
}

struct KuwoError: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}
