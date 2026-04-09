//
//  RationaleBank.swift
//  mathblocker
//
//  Created by Andy Phu on 4/9/26.
//

import Foundation

actor RationaleBank {
    static let shared = RationaleBank()

    private var rationales: [String: String] = [:]
    private var loaded = false

    func load() {
        guard !loaded else { return }
        guard let url = Bundle.main.url(forResource: "rationales", withExtension: "json") else { return }
        do {
            let data = try Data(contentsOf: url)
            rationales = try JSONDecoder().decode([String: String].self, from: data)
            loaded = true
            print("RationaleBank: loaded \(rationales.count) rationales")
        } catch {
            print("RationaleBank: failed to load: \(error)")
        }
    }

    func rationale(forIndex index: Int) -> String? {
        rationales[String(index)]
    }
}
