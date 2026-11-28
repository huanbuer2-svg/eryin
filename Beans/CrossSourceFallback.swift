import Foundation

/// 跨平台兜底：当某首歌在自身平台解析不到地址时（例如 QQ 音源被上游收紧），
/// 用「歌名 + 歌手」去其他平台搜同款，拿到真实 ID 后再走音源脚本解析。
///
/// 背景：UnblockService 已有的 platformFallback 只是把「同一个 ID」换个平台去问脚本，
/// 而各平台 ID 体系不同，所以那条路必然失败。这里先搜索拿到目标平台的真实 ID。
enum CrossSourceFallback {

    /// 返回：解析结果 + 命中的其它平台歌曲
    static func resolve(
        song: Song,
        quality: ThirdPartyAudioQuality,
        strict: Bool
    ) async -> (UnblockService.Resolved, Song)? {
        let keyword = "\(song.name) \(song.artists)".trimmingCharacters(in: .whitespacesAndNewlines)
        guard !keyword.isEmpty else { return nil }

        for target in targetSources(for: song.source) {
            guard let candidates = try? await search(target, keyword: keyword) else { continue }
            guard let match = bestMatch(for: song, in: candidates) else {
                BeansLogger.shared.log("跨平台兜底：\(target.rawValue) 未找到同款 song=\(song.name)", level: .debug)
                continue
            }
            let resolved = await UnblockService.resolve(
                name: match.name,
                artists: match.artists,
                neteaseID: match.id,
                songSource: target,
                qqMid: target == .qq ? match.qqMid : nil,
                quality: quality,
                strict: strict,
                allowPlatformFallback: false
            )
            if let resolved {
                BeansLogger.shared.log(
                    "跨平台兜底命中 \(song.source.rawValue)→\(target.rawValue) song=\(song.name) match=\(match.name)/\(match.artists) via=\(resolved.sourceTitle)",
                    level: .info
                )
                return (resolved, match)
            }
            BeansLogger.shared.log("跨平台兜底：\(target.rawValue) 找到同款但解析失败 song=\(match.name)", level: .warn)
        }
        return nil
    }

    /// 兜底顺序：网易云 → 酷狗 → 酷我（脚本对这三家成功率最高）
    private static func targetSources(for source: SongSource) -> [SongSource] {
        switch source {
        case .netease: return [.kugou, .kuwo, .qq]
        case .qq: return [.netease, .kugou, .kuwo]
        case .kugou: return [.netease, .kuwo, .qq]
        case .kuwo: return [.netease, .kugou, .qq]
        case .qishui: return [.netease, .kugou, .kuwo]
        case .migu: return [.netease, .kugou, .kuwo]
        case .bilibili, .webdav: return []
        }
    }

    private static func search(_ target: SongSource, keyword: String) async throws -> [Song] {
        switch target {
        case .netease:
            return try await NetEaseAPI.shared.search(keyword: keyword, limit: 10)
        case .qq:
            return try await QQMusicAPI.shared.searchSongs(keyword: keyword, limit: 10)
        case .kugou:
            return try await KugouMusicAPI.shared.searchSongs(keyword: keyword, limit: 10)
        case .kuwo:
            return try await AdditionalCatalogSearchAPI.searchKuwo(keyword: keyword, limit: 10)
        case .migu:
            return try await AdditionalCatalogSearchAPI.searchMigu(keyword: keyword, limit: 10)
        default:
            return []
        }
    }

    // MARK: - 匹配

    private static func bestMatch(for song: Song, in candidates: [Song]) -> Song? {
        let targetTitle = normalize(song.name)
        let targetArtist = normalize(song.artists)
        guard !targetTitle.isEmpty else { return nil }

        var best: (Song, Int)?
        for candidate in candidates {
            let title = normalize(candidate.name)
            guard !title.isEmpty else { continue }
            var score = 0
            if title == targetTitle { score += 60 }
            else if title.contains(targetTitle) || targetTitle.contains(title) { score += 40 }
            let artist = normalize(candidate.artists)
            if !targetArtist.isEmpty, !artist.isEmpty {
                if artist.contains(targetArtist) || targetArtist.contains(artist) { score += 30 }
                else if sharesToken(targetArtist, artist) { score += 15 }
            }
            if score >= 40, score > (best?.1 ?? 0) {
                best = (candidate, score)
            }
        }
        return best?.0
    }

    private static func normalize(_ text: String) -> String {
        let lowered = text.lowercased()
        let stripped = lowered.unicodeScalars.filter { scalar in
            CharacterSet.alphanumerics.contains(scalar) || scalar.value > 0x2E80
        }
        return String(String.UnicodeScalarView(stripped))
    }

    private static func sharesToken(_ lhs: String, _ rhs: String) -> Bool {
        let tokens = lhs.split(whereSeparator: { "/&,、".contains($0) }).map(String.init)
        return tokens.contains { token in
            token.count >= 2 && rhs.contains(token)
        }
    }
}
