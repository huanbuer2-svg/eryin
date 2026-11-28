import SwiftUI

/// 酷我音乐登录（网页 Cookie 粘贴）+ 云端歌单一键导入本地。
struct KuwoLoginSheet: View {
    @EnvironmentObject private var theme: ThemeStore
    @Environment(\.dismiss) private var dismiss

    @ObservedObject private var auth = KuwoMusicAuth.shared

    @State private var cookieText = ""
    @State private var phase: Phase = .idle
    @State private var message = ""
    @State private var playlists: [Playlist] = []
    @State private var syncedCount = 0

    private enum Phase: Equatable {
        case idle
        case working
        case done
    }

    var body: some View {
        let _ = theme.accent
        ZStack {
            GlassBackdrop(customColor: theme.backgroundSyncAll ? theme.customBackground : nil)
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Text("登录酷我音乐")
                            .font(BeansFont.appFont(20, .bold))
                            .foregroundStyle(Color.beansLabel)
                        Spacer()
                        Button {
                            BeansHaptics.tap()
                            dismiss()
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 22))
                                .foregroundStyle(Color.beansComment)
                        }
                        .buttonStyle(GlassPressButtonStyle(scale: 0.9))
                    }

                    if auth.isLoggedIn {
                        loggedInCard
                    } else {
                        loginForm
                    }

                    if !message.isEmpty {
                        Text(message)
                            .font(BeansFont.appFont(12))
                            .foregroundStyle(phase == .done ? Color.beansSage : Color.beansComment)
                    }

                    if !playlists.isEmpty {
                        syncSection
                    }
                }
                .padding(20)
            }
            .beansScrollIndicatorsHidden()
        }
    }

    private var loginForm: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("酷我音乐没有开放登录接口，这里使用网页版 Cookie 登录：")
                .font(BeansFont.appFont(13))
                .foregroundStyle(Color.beansLabel)

            VStack(alignment: .leading, spacing: 6) {
                Text("1. 用 Safari 打开 www.kuwo.cn 并登录")
                Text("2. 用抓包工具或浏览器开发者工具复制请求头里的整条 Cookie")
                Text("3. 粘贴到下面，点「登录」")
            }
            .font(BeansFont.appFont(12))
            .foregroundStyle(Color.beansComment)

            TextEditor(text: $cookieText)
                .font(.system(size: 12, design: .monospaced))
                .frame(height: 120)
                .beansScrollContentHidden()
                .padding(10)
                .background {
                    BeansSurface(shape: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)

            Button {
                BeansHaptics.tap()
                Task { await login() }
            } label: {
                HStack {
                    if phase == .working {
                        ProgressView().controlSize(.small)
                    }
                    Text(phase == .working ? "正在登录…" : "登录")
                        .font(BeansFont.appFont(15, .semibold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background { BeansSurface(shape: Capsule()) }
            }
            .buttonStyle(GlassPressButtonStyle(scale: 0.98))
            .disabled(cookieText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || phase == .working)
        }
    }

    private var loggedInCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                KuwoBrandIcon(size: 44)
                VStack(alignment: .leading, spacing: 2) {
                    Text(auth.nickname.isEmpty ? "酷我音乐" : auth.nickname)
                        .font(BeansFont.appFont(15, .semibold))
                        .foregroundStyle(Color.beansLabel)
                    Text("UID \(auth.userId)")
                        .font(BeansFont.appFont(12))
                        .foregroundStyle(Color.beansComment)
                }
                Spacer()
            }
            if playlists.isEmpty {
                Button {
                    BeansHaptics.tap()
                    Task { await loadPlaylists() }
                } label: {
                    Text("读取我的酷我歌单")
                        .font(BeansFont.appFont(13, .medium))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background { BeansSurface(shape: Capsule()) }
                }
                .buttonStyle(GlassPressButtonStyle(scale: 0.98))
            }
        }
    }

    private var syncSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("我的酷我歌单（\(playlists.count)）")
                .font(BeansFont.appFont(14, .semibold))
                .foregroundStyle(Color.beansLabel)
            ForEach(playlists.prefix(30)) { playlist in
                HStack(spacing: 10) {
                    Text(playlist.name)
                        .font(BeansFont.appFont(13))
                        .foregroundStyle(Color.beansLabel)
                        .lineLimit(1)
                    Spacer()
                    Text("\(playlist.trackCount) 首")
                        .font(BeansFont.appFont(11))
                        .foregroundStyle(Color.beansComment)
                }
            }
            Button {
                BeansHaptics.tap()
                Task { await syncToLocal() }
            } label: {
                HStack {
                    if phase == .working { ProgressView().controlSize(.small) }
                    Text(phase == .working ? "正在导入…" : "全部导入本地歌单")
                        .font(BeansFont.appFont(15, .semibold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background { BeansSurface(shape: Capsule()) }
            }
            .buttonStyle(GlassPressButtonStyle(scale: 0.98))
            .disabled(phase == .working)
        }
    }

    // MARK: - 动作

    @MainActor
    private func login() async {
        phase = .working
        message = ""
        do {
            let cookie = cookieText.trimmingCharacters(in: .whitespacesAndNewlines)
            let user = try await KuwoMusicAPI.shared.userInfo(cookie: cookie)
            auth.save(cookie: cookie, user: user)
            phase = .done
            message = "登录成功\(user.nickname.isEmpty ? "" : "：\(user.nickname)")"
            await loadPlaylists()
        } catch {
            phase = .idle
            message = "登录失败：\(error.localizedDescription)"
        }
    }

    @MainActor
    private func loadPlaylists() async {
        phase = .working
        do {
            playlists = try await KuwoMusicAPI.shared.userPlaylists(uid: auth.userId)
            phase = .idle
            message = playlists.isEmpty ? "没有读取到酷我歌单（可能接口字段变了，请把日志发我）" : ""
        } catch {
            phase = .idle
            message = "读取歌单失败：\(error.localizedDescription)"
        }
    }

    @MainActor
    private func syncToLocal() async {
        phase = .working
        var done = 0
        for playlist in playlists.prefix(30) {
            if Task.isCancelled { break }
            do {
                let songs = try await AdditionalCatalogSearchAPI.playlistSongs(source: .kuwo, id: playlist.id)
                guard !songs.isEmpty else { continue }
                LocalLibraryStore.shared.createPlaylist(
                    name: "酷我 · \(playlist.name)",
                    songs: songs,
                    coverURL: playlist.coverURL,
                    sourceName: "酷我音乐"
                )
                done += 1
            } catch {
                BeansLogger.shared.log("酷我歌单导入失败 id=\(playlist.id) error=\(error.localizedDescription)", level: .warn)
            }
        }
        syncedCount = done
        phase = .done
        message = done == 0 ? "没有可导入的歌单" : "已导入 \(done) 个歌单到本地音乐库"
    }
}

// MARK: - 品牌图标

struct KuwoBrandIcon: View {
    var size: CGFloat = 44

    var body: some View {
        RoundedRectangle(cornerRadius: size * 0.26, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [Color(red: 0.20, green: 0.47, blue: 0.98), Color(red: 0.10, green: 0.30, blue: 0.80)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(width: size, height: size)
            .overlay {
                Image(systemName: "music.note")
                    .font(.system(size: size * 0.46, weight: .bold))
                    .foregroundStyle(.white)
            }
            .shadow(color: Color(red: 0.10, green: 0.30, blue: 0.80).opacity(0.25), radius: 8, y: 4)
    }
}
