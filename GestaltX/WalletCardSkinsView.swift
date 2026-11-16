// SPDX-License-Identifier: GPL-3.0-only
// Copyright (C) 2026 Bonnie-Blue-AIO contributors
//
// Wallet card skins UI for GestaltX. Artwork apply/restore inspired by
// AirCard-iOS (MIT). Writes use worse_query via WalletCardSkinsModel.
import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

struct WalletCardSkinsView: View {
    @StateObject private var model = WalletCardSkinsModel()
    @State private var showImporter = false
    @State private var showManualID = false
    @State private var manualID = ""
    @State private var askRestore = false
    @State private var photoItem: PhotosPickerItem?

    var body: some View {
        List {
            Section {
                Text(L("Apply custom artwork to Apple Wallet cards by writing into /var/mobile/Library/Passes/Cards using worse_query. Live Apple Pay scanning still needs AirCard/Airlift — paste a card ID or Refresh after Wallet has created passes."))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section(L("Card")) {
                if model.cards.isEmpty {
                    Text(L("No cards discovered yet."))
                        .foregroundStyle(.secondary)
                } else {
                    Picker(L("Card ID"), selection: $model.selectedCardID) {
                        ForEach(model.cards) { card in
                            Text(card.displayName).tag(card.id)
                        }
                    }
                }
                Button(L("Refresh Card List")) { model.refreshCardList() }
                    .disabled(!model.isReady || model.isBusy)
                Button(L("Enter Card ID…")) { showManualID = true }
                    .disabled(!model.isReady || model.isBusy)
            }

            Section(L("Artwork")) {
                PhotosPicker(selection: $photoItem, matching: .images) {
                    Label(L("Choose Photo"), systemImage: "photo")
                }
                .disabled(!model.isReady || model.isBusy)
                Button(L("Import Image File…")) { showImporter = true }
                    .disabled(!model.isReady || model.isBusy)
                if let preview = model.previewImage {
                    Image(uiImage: preview)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 160)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                }
            }

            Section {
                Button {
                    _ = model.apply()
                } label: {
                    Label(L("Apply Card Skin"), systemImage: "checkmark.circle.fill")
                }
                .disabled(!model.isReady || model.isBusy || model.previewImage == nil || model.selectedCardID.isEmpty)

                Button { askRestore = true } label: {
                    Label(L("Restore Original"), systemImage: "arrow.uturn.backward")
                }
                .disabled(!model.isReady || model.isBusy || model.selectedCardID.isEmpty || !model.hasBackup)
            }

            if let status = model.status {
                Section { Text(status).font(.footnote).foregroundStyle(.secondary) }
            }
        }
        .navigationTitle(L("Wallet Card Skins"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if model.isBusy { ProgressView() }
            }
        }
        .task { await model.prepare() }
        .onDisappear { model.shutdown() }
        .onChange(of: model.selectedCardID) { _, _ in model.noteSelectionChanged() }
        .onChange(of: photoItem) { _, newItem in
            guard let newItem else { return }
            Task {
                if let data = try? await newItem.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    await MainActor.run { model.loadImage(image) }
                }
            }
        }
        .sheet(isPresented: $showImporter) {
            CustomizationFilePicker(allowedTypes: [.image, .png, .jpeg, .data]) { result in
                showImporter = false
                switch result {
                case .success(let url): model.loadImage(from: url)
                case .failure(let error): model.message = error.localizedDescription
                }
            }
            .ignoresSafeArea()
        }
        .alert(L("Card ID"), isPresented: $showManualID) {
            TextField(L("Card ID"), text: $manualID)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            Button(L("Cancel"), role: .cancel) {}
            Button(L("Use")) {
                model.setManualCardID(manualID)
                manualID = ""
            }
        } message: {
            Text(L("Paste the pass/card id (the folder name under Passes/Cards, without .pkpass)."))
        }
        .alert(L("Restore Original"), isPresented: $askRestore) {
            Button(L("Cancel"), role: .cancel) {}
            Button(L("Restore"), role: .destructive) { _ = model.restore() }
        } message: {
            Text(L("Restore only artwork GestaltX backed up for this card. Force-close Wallet afterward."))
        }
        .alert(L("GestaltX"), isPresented: Binding(
            get: { model.message != nil },
            set: { if !$0 { model.message = nil } }
        )) {
            Button(L("OK"), role: .cancel) { model.message = nil }
        } message: {
            Text(model.message ?? "")
        }
    }
}
