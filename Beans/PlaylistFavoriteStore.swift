import Foundation
import Combine

/// 歌单收藏（本地保存）。用于搜索/歌单广场里看到的歌单，随时收藏后在音乐库查看。
final class PlaylistFavoriteStore: ObservableObject {
    static let shared = PlaylistFavoriteStore()

    @Published private(set) var favorites: [Playlist] = []

    private let key = "beans.favorite.playlists.v1"
    private let defaults = UserDefaults.standard

    private init() {
        guard let data = defaults.data(forKey: key),
              let list = try? JSONDecoder().decode([Playlist].self, from: data) else { return }
        favorites = list
    }

    func isFavorite(_ playlist: Playlist) -> Bool {
        favorites.contains { $0.id == playlist.id && $0.source == playlist.source }
    }

    @discardableResult
    func toggle(_ playlist: Playlist) -> Bool {
        if isFavorite(playlist) {
            favorites.removeAll { $0.id == playlist.id && $0.source == playlist.source }
        } else {
            favorites.insert(playlist, at: 0)
        }
        save()
        return isFavorite(playlist)
    }

    func remove(_ playlist: Playlist) {
        guard isFavorite(playlist) else { return }
        favorites.removeAll { $0.id == playlist.id && $0.source == playlist.source }
        save()
    }

    private func save() {
        if let data = try? JSONEncoder().encode(favorites) {
            defaults.set(data, forKey: key)
        }
    }
}
