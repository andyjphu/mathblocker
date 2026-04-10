//
//  PackManager.swift
//  mathblocker
//
//  Created by Andy Phu on 4/9/26.
//

import Foundation

/// A downloadable question pack listed in the remote manifest.
struct QuestionPack: Codable, Identifiable {
    let id: String
    let name: String
    let description: String
    let count: Int
    let sizeMB: Double
    let difficulty: String
    let url: String
}

/// Remote manifest listing all available packs.
struct PackManifest: Codable {
    let packs: [QuestionPack]
}

/// Manages fetching the manifest, downloading/deleting question packs,
/// and tracking which packs are installed locally.
@Observable
class PackManager {
    static let shared = PackManager()
    static let manifestURL = URL(string: "https://cdn.recursn.com/manifest.json")!

    var availablePacks: [QuestionPack] = []
    var downloadingPacks: Set<String> = []
    var downloadProgress: [String: Double] = [:]
    var errorMessage: String?
    /// Observable set of installed pack IDs. Updated on download/delete
    /// so SwiftUI re-renders the pack list immediately.
    var installedIds: Set<String> = []

    private let fileManager = FileManager.default

    init() {
        refreshInstalledIds()
    }

    /// Directory where downloaded packs are stored.
    private var packsDirectory: URL {
        let docs = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        let dir = docs.appendingPathComponent("QuestionPacks", isDirectory: true)
        try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    /// Re-scans the packs directory and updates `installedIds`.
    func refreshInstalledIds() {
        let files = (try? fileManager.contentsOfDirectory(at: packsDirectory, includingPropertiesForKeys: nil)) ?? []
        let ids = files
            .filter { $0.pathExtension == "json" }
            .map { $0.deletingPathExtension().lastPathComponent }
        installedIds = Set(ids)
    }

    /// Fetch the manifest from the server.
    func fetchManifest() async {
        do {
            let (data, _) = try await URLSession.shared.data(from: Self.manifestURL)
            let manifest = try JSONDecoder().decode(PackManifest.self, from: data)
            await MainActor.run {
                self.availablePacks = manifest.packs
                self.errorMessage = nil
                self.refreshInstalledIds()
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "couldn't load packs: \(error.localizedDescription)"
            }
        }
    }

    /// Whether a pack is downloaded locally.
    func isInstalled(_ packId: String) -> Bool {
        installedIds.contains(packId)
    }

    /// Download a pack from its URL and save locally.
    func download(_ pack: QuestionPack) async {
        guard !downloadingPacks.contains(pack.id) else { return }

        await MainActor.run {
            downloadingPacks.insert(pack.id)
            downloadProgress[pack.id] = 0
        }

        do {
            guard let url = URL(string: pack.url) else { return }
            let (tempURL, _) = try await URLSession.shared.download(from: url)
            let dest = localPath(for: pack.id)
            try? fileManager.removeItem(at: dest)
            try fileManager.moveItem(at: tempURL, to: dest)

            await MainActor.run {
                downloadingPacks.remove(pack.id)
                downloadProgress.removeValue(forKey: pack.id)
                installedIds.insert(pack.id)
            }
        } catch {
            await MainActor.run {
                downloadingPacks.remove(pack.id)
                downloadProgress.removeValue(forKey: pack.id)
                errorMessage = "download failed: \(error.localizedDescription)"
            }
        }
    }

    /// Delete a downloaded pack.
    func delete(_ packId: String) {
        try? fileManager.removeItem(at: localPath(for: packId))
        installedIds.remove(packId)
    }

    /// Load questions from all installed packs.
    func loadInstalledQuestions() -> [BundledQuestion] {
        var all: [BundledQuestion] = []
        for pack in availablePacks where isInstalled(pack.id) {
            let path = localPath(for: pack.id)
            guard let data = try? Data(contentsOf: path),
                  let questions = try? JSONDecoder().decode([BundledQuestion].self, from: data)
            else { continue }
            all.append(contentsOf: questions)
        }
        return all
    }

    /// IDs of all installed packs.
    var installedPackIds: [String] {
        Array(installedIds).sorted()
    }

    private func localPath(for packId: String) -> URL {
        packsDirectory.appendingPathComponent("\(packId).json")
    }
}
