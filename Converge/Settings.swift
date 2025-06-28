//
//  Settings.swift
//  Converge
//
//  Created by Hariz Shirazi on 2025-06-26.
//

import SwiftUI

// not using the new observable framework here bc i'm SO not used to it :/
final class Settings: @unchecked Sendable, ObservableObject {
    static let shared = Settings()
    @Published/*AppStorage("WineInstalled")*/ var isWineInstalled: Bool
    init() {
        // stupid workaround since i used to store this in UserDefaults
        _isWineInstalled = Published(initialValue: {
            return FileManager.default.fileExists(atPath: URL.applicationSupportDirectory.appendingPathComponent("Converge/wine/bin/wine64", isDirectory: false).path)
        }())
    }
}
