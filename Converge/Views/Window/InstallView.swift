//
//  InstallView.swift
//  Converge
//
//  Created by Hariz Shirazi on 2025-06-26.
//

import SwiftUI

struct InstallView: View {
    @ObservedObject var settings = Settings.shared
    @State var showPicker = false
    @State private var inProgress = false
    
    var body: some View {
        VStack {
            Text("Wine Installation")
                .font(.largeTitle)
                .padding(.bottom, 8)
            Text((try! AttributedString(markdown: "Please download the latest release from [here](https://github.com/BomberFish/Converge-build-scripts/releases/latest) and extract it.")))
                .textSelection(.enabled)
                .padding(.bottom, 14)
            if !inProgress {
                Button("Choose Converge.bundle") {
                    showPicker = true
                }
            } else {
                ProgressView("Copying files...")
                    .controlSize(.large)
            }
        }
            .fileImporter(
                isPresented: $showPicker,
                allowedContentTypes: [.item],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let urls):
                    guard let droppedURL = urls.first else { return }
                    inProgress = true
                    Task {
                            let fm = FileManager.default
                            
                            guard droppedURL.lastPathComponent == "Converge.bundle" else {
                                return
                            }
                            
                            let sourceURL = droppedURL.appendingPathComponent("wine", isDirectory: true)
                            
                            guard fm.fileExists(atPath: sourceURL.path) else {
                                return
                            }
                            
                            do {
                                let destinationParentDir = URL.applicationSupportDirectory.appendingPathComponent("Converge", isDirectory: true)
                                
                                try fm.createDirectory(at: destinationParentDir, withIntermediateDirectories: true, attributes: nil)
                                try fm.createDirectory(at: destinationParentDir.appendingPathComponent("Bottles", isDirectory: true), withIntermediateDirectories: true, attributes: nil)
                                
                                let destinationURL = destinationParentDir.appendingPathComponent("wine", isDirectory: true)
                                
                                if fm.fileExists(atPath: destinationURL.path) {
                                    try fm.removeItem(at: destinationURL)
                                }
                                
                                try fm.copyItem(at: sourceURL, to: destinationURL)
                                settings.isWineInstalled = true
                            } catch {
                                print("Error copying files: \(error.localizedDescription)")
                            }
                        
                    }
                    inProgress = false
                case .failure(let error):
                    print("Error importing file: \(error.localizedDescription)")
                }
            }
        
        .padding()
    }
}

#Preview {
    InstallView()
}
