// SPDX-License-Identifier: GPL-3.0-only
// Copyright (C) 2026 Bonnie-Blue-AIO contributors
//
// Wallet card skin apply/restore adapted from AirCard-iOS (Mak5er / Johnny Franks),
// MIT License — https://github.com/Mak5er/AirCard-iOS
// File writes use GestaltX acquirePath / worse_query instead of Airlift.
import Combine
import Foundation
import ImageIO
import UIKit
import UniformTypeIdentifiers

enum WalletCardSkinNames {
    static let passesRoot = "/var/mobile/Library/Passes/Cards"
    static let skinFiles = [
        "cardBackgroundCombined@3x.png", "cardBackgroundCombined@2x.png",
        "diffuse@3x.png", "diffuse@2x.png",
        "background@3x.png", "background@2x.png",
        "strip@3x.png", "strip@2x.png",
        "cardBackgroundCombined.pdf", "background.pdf", "strip.pdf"
    ]
    static let cacheExts = [".cache", ".pkcache"]
    static let originalsDirName = "GestaltXWalletCardOriginals"
}

struct WalletCardEntry: Identifiable, Equatable {
    let id: String
    var displayName: String { String(id.prefix(12)) + (id.count > 12 ? "…" : "") }
}

@MainActor
final class WalletCardSkinsModel: ObservableObject {
    @Published var cards: [WalletCardEntry] = []
    @Published var selectedCardID: String = ""
    @Published var previewImage: UIImage?
    @Published var isReady = false
    @Published var isBusy = false
    @Published var status: String?
    @Published var message: String?
    @Published private(set) var hasBackup = false

    private let fm = FileManager.default
    private var activeLease: Int64 = -1
    private var imageData: Data?

    func shutdown() { releaseLease() }

    func prepare() async {
        guard !isReady else { return }
        isBusy = true
        status = L("Opening Passes folder…")
        defer { isBusy = false }
        #if targetEnvironment(simulator)
        message = L("Device access is unavailable in the Simulator.")
        status = nil
        return
        #else
        guard acquire(WalletCardSkinNames.passesRoot) else {
            message = L("Could not open /var/mobile/Library/Passes/Cards with worse_query. This path may need Airlift instead.")
            status = nil
            return
        }
        refreshCardList()
        refreshBackupFlag()
        isReady = true
        status = cards.isEmpty
            ? L("Ready. No cards listed yet — paste a card ID or open Wallet once, then tap Refresh.")
            : L("Ready. Pick a card, choose artwork, Apply. Restore Original undoes GestaltX skins.")
        #endif
    }

    func refreshCardList() {
        let root = URL(fileURLWithPath: WalletCardSkinNames.passesRoot, isDirectory: true)
        guard let urls = try? fm.contentsOfDirectory(at: root, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) else {
            cards = []
            return
        }
        var ids = Set<String>()
        for url in urls {
            let name = url.lastPathComponent
            for ext in [".pkpass", ".cache", ".pkcache"] where name.hasSuffix(ext) {
                ids.insert(String(name.dropLast(ext.count)))
            }
            if url.hasDirectoryPath, name.hasSuffix(".pkpass") {
                ids.insert(String(name.dropLast(".pkpass".count)))
            }
        }
        let previous = selectedCardID
        cards = ids.sorted().map { WalletCardEntry(id: $0) }
        if !previous.isEmpty, !cards.contains(where: { $0.id == previous }) {
            cards.insert(WalletCardEntry(id: previous), at: 0)
        }
        if selectedCardID.isEmpty, let first = cards.first { selectedCardID = first.id }
        refreshBackupFlag()
    }

    func noteSelectionChanged() { refreshBackupFlag() }

    func setManualCardID(_ raw: String) {
        let cleaned = Self.cleanCardID(raw)
        guard !cleaned.isEmpty else { return }
        selectedCardID = cleaned
        if !cards.contains(where: { $0.id == cleaned }) {
            cards.insert(WalletCardEntry(id: cleaned), at: 0)
        }
        refreshBackupFlag()
    }

    func loadImage(from url: URL) {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        guard let data = try? Data(contentsOf: url),
              let image = Self.safeImage(from: data) else {
            message = L("Could not read that image.")
            return
        }
        imageData = Self.prepareCardImage(from: image)
        previewImage = imageData.flatMap { UIImage(data: $0) } ?? image
        message = nil
    }

    func loadImage(_ image: UIImage) {
        imageData = Self.prepareCardImage(from: image)
        previewImage = imageData.flatMap { UIImage(data: $0) } ?? image
        message = nil
    }

    @discardableResult
    func apply() -> Bool {
        guard isReady else { return false }
        let cardID = Self.cleanCardID(selectedCardID)
        guard !cardID.isEmpty else {
            message = L("Enter or select a card ID first.")
            return false
        }
        guard let sourceData = imageData, let sourceImage = UIImage(data: sourceData) ?? previewImage else {
            message = L("Choose card artwork first.")
            return false
        }
        guard acquire(WalletCardSkinNames.passesRoot) else {
            message = L("Could not reopen the Passes folder for writing.")
            return false
        }
        let skins = Self.prepareAllCardSkins(from: sourceImage)
        guard !skins.isEmpty else {
            message = L("Failed to build card skin files.")
            return false
        }
        let pkpass = pkpassURL(for: cardID)
        do {
            if !fm.fileExists(atPath: pkpass.path) {
                try fm.createDirectory(at: pkpass, withIntermediateDirectories: true)
            }
            try backupOriginals(cardID: cardID, pkpass: pkpass, skins: skins)
            for (name, data) in skins {
                try data.write(to: pkpass.appendingPathComponent(name), options: .atomic)
            }
            invalidateCaches(cardID: cardID)
            refreshBackupFlag()
            message = L("Skins applied. Force-close Wallet (swipe away), then reopen to see the card.")
            log("Wallet Card Skins: applied \(skins.count) files to \(cardID.prefix(12))")
            return true
        } catch {
            message = L("Failed to write card skins: ") + error.localizedDescription
            log("Wallet Card Skins: apply failed: \(error.localizedDescription)")
            return false
        }
    }

    @discardableResult
    func restore() -> Bool {
        guard isReady else { return false }
        let cardID = Self.cleanCardID(selectedCardID)
        guard !cardID.isEmpty else {
            message = L("Enter or select a card ID first.")
            return false
        }
        guard acquire(WalletCardSkinNames.passesRoot) else {
            message = L("Could not reopen the Passes folder for writing.")
            return false
        }
        let backup = backupDir(for: cardID)
        guard fm.fileExists(atPath: backup.path) else {
            message = L("No GestaltX backup for this card yet. Restore Original only undoes skins this app applied.")
            return false
        }
        let pkpass = pkpassURL(for: cardID)
        do {
            let files = try fm.contentsOfDirectory(at: backup, includingPropertiesForKeys: nil)
            for file in files {
                let dest = pkpass.appendingPathComponent(file.lastPathComponent)
                if fm.fileExists(atPath: dest.path) { try fm.removeItem(at: dest) }
                try fm.copyItem(at: file, to: dest)
            }
            // Remove skin files we added that were originally absent (marked empty).
            for name in WalletCardSkinNames.skinFiles {
                let marker = backup.appendingPathComponent(name + ".absent")
                if fm.fileExists(atPath: marker.path) {
                    let dest = pkpass.appendingPathComponent(name)
                    if fm.fileExists(atPath: dest.path) { try fm.removeItem(at: dest) }
                }
            }
            invalidateCaches(cardID: cardID)
            message = L("Original artwork restored. Force-close Wallet, then reopen.")
            log("Wallet Card Skins: restored \(cardID.prefix(12))")
            return true
        } catch {
            message = L("Restore failed: ") + error.localizedDescription
            return false
        }
    }

    // MARK: - Paths / lease

    private func pkpassURL(for cardID: String) -> URL {
        URL(fileURLWithPath: WalletCardSkinNames.passesRoot, isDirectory: true)
            .appendingPathComponent(cardID + ".pkpass", isDirectory: true)
    }

    private func backupRoot() -> URL {
        let docs = fm.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent(WalletCardSkinNames.originalsDirName, isDirectory: true)
    }

    private func backupDir(for cardID: String) -> URL {
        let safe = cardID.replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "+", with: "-")
        return backupRoot().appendingPathComponent(safe, isDirectory: true)
    }

    private func refreshBackupFlag() {
        let id = Self.cleanCardID(selectedCardID)
        hasBackup = !id.isEmpty && fm.fileExists(atPath: backupDir(for: id).path)
    }

    private func backupOriginals(cardID: String, pkpass: URL, skins: [String: Data]) throws {
        let dir = backupDir(for: cardID)
        if !fm.fileExists(atPath: dir.path) {
            try fm.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        // Only snapshot once so Restore Original returns pre-GestaltX artwork.
        let marker = dir.appendingPathComponent(".snapshotted")
        if fm.fileExists(atPath: marker.path) { return }
        for name in skins.keys {
            let src = pkpass.appendingPathComponent(name)
            if fm.fileExists(atPath: src.path) {
                let dest = dir.appendingPathComponent(name)
                if fm.fileExists(atPath: dest.path) { try fm.removeItem(at: dest) }
                try fm.copyItem(at: src, to: dest)
            } else {
                try Data().write(to: dir.appendingPathComponent(name + ".absent"), options: .atomic)
            }
        }
        try Data().write(to: marker, options: .atomic)
    }

    private func invalidateCaches(cardID: String) {
        let root = URL(fileURLWithPath: WalletCardSkinNames.passesRoot, isDirectory: true)
        for ext in WalletCardSkinNames.cacheExts {
            let cache = root.appendingPathComponent(cardID + ext, isDirectory: true)
            guard fm.fileExists(atPath: cache.path) else { continue }
            for leaf in ["FrontFace", "Preview", "PlaceHolder"] {
                let url = cache.appendingPathComponent(leaf)
                try? Data("corrupted".utf8).write(to: url, options: .atomic)
            }
        }
    }

    @discardableResult
    private func acquire(_ path: String) -> Bool {
        releaseLease()
        #if os(iOS) && !targetEnvironment(simulator)
        let lease = GXCustomizationAccess.acquirePath(path)
        guard lease >= 0 else { return false }
        activeLease = lease
        return true
        #else
        return false
        #endif
    }

    private func releaseLease() {
        #if os(iOS) && !targetEnvironment(simulator)
        if activeLease >= 0 {
            worse_query_release(activeLease)
            activeLease = -1
        }
        #endif
    }

    private func log(_ text: String) {
        NotificationCenter.default.post(
            name: Notification.Name("GestaltX.worse_query.log"),
            object: nil,
            userInfo: ["message": text]
        )
    }

    // MARK: - Image helpers (from AirCard ImageEngine, MIT)

    static func cleanCardID(_ raw: String) -> String {
        var s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if let range = s.range(of: "/Cards/", options: .caseInsensitive) {
            s = String(s[range.upperBound...])
        }
        for ext in [".pkpass", ".cache", ".pkcache"] where s.lowercased().hasSuffix(ext) {
            s = String(s.dropLast(ext.count))
        }
        if let slash = s.lastIndex(of: "/") {
            s = String(s[s.index(after: slash)...])
        }
        return s.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func safeImage(from data: Data, maxDimension: CGFloat = 2048) -> UIImage? {
        let options = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let source = CGImageSourceCreateWithData(data as CFData, options) else {
            return UIImage(data: data)
        }
        let downsample = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxDimension
        ] as CFDictionary
        if let cg = CGImageSourceCreateThumbnailAtIndex(source, 0, downsample) {
            return UIImage(cgImage: cg)
        }
        return UIImage(data: data)
    }

    static func prepareCardImage(from image: UIImage) -> Data? {
        resizeImage(normalize(image, maxDimension: 2560), targetSize: CGSize(width: 1536, height: 969))
    }

    static func prepareAllCardSkins(from image: UIImage) -> [String: Data] {
        let normalized = normalize(image, maxDimension: 2560)
        var skins: [String: Data] = [:]
        if let data3x = resizeImage(normalized, targetSize: CGSize(width: 1536, height: 969)) {
            for name in ["cardBackgroundCombined@3x.png", "diffuse@3x.png", "background@3x.png", "strip@3x.png"] {
                skins[name] = data3x
            }
        }
        if let data2x = resizeImage(normalized, targetSize: CGSize(width: 1024, height: 646)) {
            for name in ["cardBackgroundCombined@2x.png", "diffuse@2x.png", "background@2x.png", "strip@2x.png"] {
                skins[name] = data2x
            }
        }
        let pdfRect = CGRect(origin: .zero, size: CGSize(width: 1536, height: 969))
        let pdfData = UIGraphicsPDFRenderer(bounds: pdfRect).pdfData { ctx in
            ctx.beginPage()
            normalized.draw(in: pdfRect)
        }
        skins["cardBackgroundCombined.pdf"] = pdfData
        skins["background.pdf"] = pdfData
        skins["strip.pdf"] = pdfData
        return skins
    }

    private static func normalize(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
        let size = image.size
        guard size.width > 0, size.height > 0 else { return image }
        let scale = min(1.0, maxDimension / max(size.width, size.height))
        let target = CGSize(width: max(1, floor(size.width * scale)), height: max(1, floor(size.height * scale)))
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false
        return UIGraphicsImageRenderer(size: target, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: target))
        }
    }

    private static func resizeImage(_ image: UIImage, targetSize: CGSize) -> Data? {
        let imgSize = image.size
        guard imgSize.width > 0, imgSize.height > 0 else { return nil }
        let scale = max(targetSize.width / imgSize.width, targetSize.height / imgSize.height)
        let scaled = CGSize(width: imgSize.width * scale, height: imgSize.height * scale)
        let origin = CGPoint(x: (targetSize.width - scaled.width) / 2, y: (targetSize.height - scaled.height) / 2)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let out = UIGraphicsImageRenderer(size: targetSize, format: format).image { _ in
            image.draw(in: CGRect(origin: origin, size: scaled))
        }
        return out.pngData()
    }
}
