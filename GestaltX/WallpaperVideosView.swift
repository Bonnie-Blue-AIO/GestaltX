// SPDX-License-Identifier: GPL-3.0-only
// Videos screen ported from Pocket Poster's VideoView by leminlimez (GPL-3.0):
// https://github.com/leminlimez/Pocket-Poster. See Licenses/Pocket-Poster-GPL-3.0.txt.
import PhotosUI
import SwiftUI

struct WallpaperVideosView: View {
    @ObservedObject var model: CustomizationModel
    @AppStorage("GestaltX.Wallpapers.ignoreVideoDurationLimit") private var ignoreDurationLimit = false
    @State private var pickerItems: [PhotosPickerItem] = []
    @State private var loading = false
    @State private var confirmApply = false
    @State private var presentationOwner = UUID()
    @State private var page = 0
    @State private var now = Date()
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var remaining: Int { max(0, WallpaperVideos.maximumVideos - model.videos.count) }
    private var limit: Int { Int(ignoreDurationLimit ? WallpaperVideos.extendedDuration : WallpaperVideos.maximumDuration) }

    var body: some View {
        List {
            Section {
                phoneCarousel
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
            } footer: {
                Text(L("Pick a short video. GestaltX converts it into a Collections wallpaper and writes it with worse_query. No PosterBoard app hash is required."))
            }

            Section {
                Toggle(L("Ignore 12-Second Limit"), isOn: $ignoreDurationLimit)
            } footer: {
                Text(String(format: L("Allows videos up to %d seconds. Longer videos create much larger wallpapers and may fail to load in PosterBoard."), Int(WallpaperVideos.extendedDuration)))
            }

            Section {
                Button { confirmApply = true } label: {
                    Label(L("Create & Apply"), systemImage: "checkmark.circle.fill")
                }
                .disabled(model.videos.isEmpty || model.busy || loading)
                Button { Task { await model.createVideoWallpaper(apply: false) } } label: {
                    Label(L("Save to Wallpaper List"), systemImage: "tray.and.arrow.down")
                }
                .disabled(model.videos.isEmpty || model.busy || loading)
            } footer: {
                if let progress = model.videoProgress {
                    Text(progress)
                } else {
                    Text(L("Videos are converted into frame-by-frame wallpapers (up to 30 fps). If a wallpaper does not appear, use Clear Collections in Wallpaper Settings, then force-close PosterBoard."))
                }
            }
        }
        .navigationTitle(L("Videos"))
        .navigationBarTitleDisplayMode(.inline)
        .disabled(model.busy)
        .toolbar { ToolbarItem(placement: .topBarTrailing) { if model.busy || loading { ProgressView() } } }
        .onAppear { model.videosScreenOpen = true }
        .onDisappear {
            model.videosScreenOpen = false
            model.setPresenting(false, owner: presentationOwner)
        }
        .onReceive(timer) { now = $0 }
        .onChange(of: confirmApply || model.message != nil, initial: true) { _, presenting in
            model.setPresenting(presenting, owner: presentationOwner)
        }
        .onChange(of: pickerItems) { _, items in
            guard !items.isEmpty else { return }
            pickerItems = []
            Task { await load(items) }
        }
        .alert(L("Apply these changes?"), isPresented: $confirmApply) {
            Button(L("Cancel"), role: .cancel) {}
            Button(L("Apply")) { Task { await model.createVideoWallpaper(apply: true) } }
        } message: { Text(L("This adds new wallpapers without replacing your existing ones. After applying, open PosterBoard and force-close it.")) }
        .alert(L("GestaltX"), isPresented: Binding(get: { model.message != nil && model.videosScreenOpen }, set: { if !$0 { model.message = nil } })) {
            Button(L("OK"), role: .cancel) { model.message = nil }
        } message: { Text(model.message ?? "") }
    }

    private var phoneCarousel: some View {
        TabView(selection: $page) {
            ForEach(Array(model.videos.enumerated()), id: \.element.id) { index, video in
                phoneCard {
                    LoopingVideoPlayer(url: video.url)
                        .scaledToFill()
                    VStack {
                        Text(Self.dateFormatter.string(from: now)).shadow(radius: 8)
                        Text(Self.timeFormatter.string(from: now))
                            .font(.system(size: 54, weight: .semibold, design: .rounded))
                            .shadow(radius: 8)
                        Spacer()
                        Text(String(format: L("%.1f s"), video.duration))
                            .font(.caption.weight(.semibold))
                            .padding(.bottom, 16)
                    }
                    .padding(.top, 32)
                    .foregroundStyle(.white)
                }
                .overlay(alignment: .topLeading) {
                    Button {
                        model.removeVideos(at: IndexSet(integer: index))
                        page = min(page, max(0, model.videos.count - (remaining > 0 ? 0 : 1)))
                    } label: {
                        Image(systemName: "minus.circle.fill")
                            .font(.title)
                            .symbolRenderingMode(.palette)
                            .foregroundStyle(.white, .red)
                            .shadow(radius: 4)
                    }
                    .offset(x: -8, y: -8)
                    .disabled(loading)
                }
                .overlay(alignment: .topTrailing) {
                    Button {
                        model.videos[index].autoReverses.toggle()
                    } label: {
                        Image(systemName: "arrow.left.arrow.right.circle.fill")
                            .font(.title)
                            .symbolRenderingMode(.palette)
                            .foregroundStyle(.white, video.autoReverses ? Color.blue : Color.gray.opacity(0.9))
                            .shadow(radius: 4)
                    }
                    .offset(x: 8, y: -8)
                    .disabled(loading)
                    .accessibilityLabel(L("Loop Back and Forth"))
                }
                .tag(index)
            }
            if remaining > 0 {
                phoneCard {
                    PhotosPicker(selection: $pickerItems, maxSelectionCount: remaining, matching: .videos, photoLibrary: .shared()) {
                        VStack(spacing: 14) {
                            if loading {
                                ProgressView()
                                Text(L("Importing…")).font(.headline)
                            } else {
                                ZStack {
                                    Circle().fill(Color.blue).frame(width: 48, height: 48)
                                    Image(systemName: "plus").font(.title).foregroundStyle(.white)
                                }
                                Text(L("Choose a Video")).font(.headline)
                            }
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .foregroundStyle(.primary)
                    }
                    .disabled(loading)
                }
                .tag(model.videos.count)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .always))
        .frame(height: 440)
    }

    @ViewBuilder
    private func phoneCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        ZStack {
            Color.black.opacity(0.65)
            content().clipped()
        }
        .frame(width: 240, height: 380)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(Color.gray, lineWidth: 3)
        }
        .shadow(radius: 6)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func load(_ items: [PhotosPickerItem]) async {
        loading = true; defer { loading = false }
        var problems: [String] = []
        for item in items {
            do {
                guard let movie = try await item.loadTransferable(type: PickedMovie.self) else {
                    problems.append(L("The video could not be read.")); continue
                }
                if let problem = await model.addVideo(movie.url, ignoreLimit: ignoreDurationLimit) {
                    problems.append(problem)
                } else {
                    page = max(0, model.videos.count - 1)
                }
            } catch {
                problems.append(error.localizedDescription)
            }
        }
        if !problems.isEmpty {
            model.message = L("Failed to Import Video") + "\n\n" + Array(Set(problems)).joined(separator: "\n")
        }
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMMM d"
        return formatter
    }()
    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = Locale.current.hourCycle == .zeroToEleven || Locale.current.hourCycle == .oneToTwelve ? "h:mm" : "HH:mm"
        return formatter
    }()
}
