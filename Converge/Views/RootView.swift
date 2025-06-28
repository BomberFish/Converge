//
//  RootView.swift
//  Converge
//
//  Created by Hariz Shirazi on 2025-06-26.
//

import SwiftUI

struct RootView: View {
    @ObservedObject var settings = Settings.shared
    var body: some View {
        if settings.isWineInstalled {
            ContentView()
        } else {
            InstallView()
        }
    }
}

#Preview {
    RootView()
}
