//
//  PacksView.swift
//  mathblocker
//
//  Created by Andy Phu on 4/9/26.
//

import SwiftUI

/// Browse, download, select, and delete question packs.
struct PacksView: View {
    @Binding var selectedSource: String
    @State private var packManager = PackManager.shared
    @State private var hasLoaded = false
    @State private var availableSources: [String] = []

    var body: some View {
        List {
            // Active pack selector
            Section {
                activeRow(id: "all", name: "all packs", subtitle: "pull from everything installed")

                activeRow(
                    id: "hendrycks_math",
                    name: "hendrycks math",
                    subtitle: "bundled · competition math (AMC, AIME) · 5,136 questions",
                    alwaysAvailable: true
                )

                ForEach(packManager.availablePacks) { pack in
                    if pack.id != "hendrycks_math" {
                        activeRow(
                            id: pack.id,
                            name: pack.name.lowercased(),
                            subtitle: packSubtitle(pack),
                            pack: pack
                        )
                    }
                }
            } header: {
                Text("question packs")
            } footer: {
                Text("tap to select · download icon to install · swipe to delete")
            }
            .listRowBackground(Theme.cardBackground)

            if let error = packManager.errorMessage {
                Section {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
                .listRowBackground(Theme.cardBackground)
            }
        }
        .fontDesign(.serif)
        .scrollContentBackground(.hidden)
        .background { FrostedBackground(image: "olive-mountain") }
        .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
        .navigationTitle("")
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("Question Packs")
                    .font(Theme.titleFont(size: 20))
            }
        }
        .task {
            if !hasLoaded {
                await packManager.fetchManifest()
                hasLoaded = true
            }
        }
    }

    private func activeRow(
        id: String,
        name: String,
        subtitle: String,
        alwaysAvailable: Bool = false,
        pack: QuestionPack? = nil
    ) -> some View {
        let isSelected = selectedSource == id
        let isInstalled = alwaysAvailable || packManager.isInstalled(id)
        let isDownloading = packManager.downloadingPacks.contains(id)

        return Button {
            if isInstalled || alwaysAvailable || id == "all" {
                selectedSource = id
            }
        } label: {
            HStack(spacing: 12) {
                // Selection indicator
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? .accent : .secondary)
                    .font(.title3)

                // Info
                VStack(alignment: .leading, spacing: 2) {
                    Text(name)
                        .font(.subheadline)
                        .fontWeight(isSelected ? .semibold : .regular)
                        .foregroundStyle(.primary)

                    Text(subtitle)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                // Download / status
                if isDownloading {
                    ProgressView()
                } else if !isInstalled, let pack {
                    Button {
                        Task {
                            await packManager.download(pack)
                            await QuestionBank.shared.reload()
                        }
                    } label: {
                        Image(systemName: "arrow.down.circle")
                            .foregroundStyle(.accent)
                            .font(.title3)
                    }
                }
            }
        }
        .swipeActions(edge: .trailing) {
            if isInstalled && !alwaysAvailable && id != "all" {
                Button(role: .destructive) {
                    packManager.delete(id)
                    if selectedSource == id {
                        selectedSource = "hendrycks_math"
                    }
                    Task { await QuestionBank.shared.reload() }
                } label: {
                    Label("delete", systemImage: "trash")
                }
            }
        }
    }

    private func packSubtitle(_ pack: QuestionPack) -> String {
        let status = packManager.isInstalled(pack.id) ? "installed" : "\(String(format: "%.1f", pack.sizeMB)) MB"
        return "\(status) · \(pack.count) questions · \(pack.description)"
    }
}
