//
//  PacksView.swift
//  mathblocker
//
//  Created by Andy Phu on 4/9/26.
//

import SwiftUI

/// Browse and download question packs from cdn.recursn.com.
struct PacksView: View {
    @State private var packManager = PackManager.shared
    @State private var hasLoaded = false

    var body: some View {
        List {
            if let error = packManager.errorMessage {
                Section {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
                .listRowBackground(Theme.cardBackground)
            }

            Section {
                ForEach(packManager.availablePacks) { pack in
                    packRow(pack)
                }
            } header: {
                Text("available packs")
            } footer: {
                Text("packs are downloaded to your device. you can delete them anytime.")
            }
            .listRowBackground(Theme.cardBackground)
        }
        .fontDesign(.serif)
        .scrollContentBackground(.hidden)
        .background { FrostedBackground(image: "olive-mountain") }
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

    private func packRow(_ pack: QuestionPack) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(pack.name)
                        .font(.headline)

                    Text(pack.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text("\(pack.count) questions · \(String(format: "%.1f", pack.sizeMB)) MB")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }

                Spacer()

                if packManager.downloadingPacks.contains(pack.id) {
                    ProgressView()
                } else if packManager.isInstalled(pack.id) {
                    Menu {
                        Button(role: .destructive) {
                            packManager.delete(pack.id)
                            Task {
                                await QuestionBank.shared.reload()
                            }
                        } label: {
                            Label("delete", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                            .font(.title3)
                    }
                } else {
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
        .padding(.vertical, 4)
    }
}
