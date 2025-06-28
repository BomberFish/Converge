//
//  InstallView.swift
//  Converge
//
//  Created by Hariz Shirazi on 2025-06-26.
//

import SwiftUI

struct InstallView: View {
    @ObservedObject var settings = Settings.shared
    @State private var inProgress = false
    
    @State private var showAlert = false
   @State private var alertTitle = ""
   @State private var alertMessage = ""
    
    
    var body: some View {
        let dropDelegate = WineDropDelegate(
            inProgress: $inProgress,
            showAlert: $showAlert,
            alertTitle: $alertTitle,
            alertMessage: $alertMessage
        )
        VStack {
            Text("Wine Installation")
                .font(.largeTitle)
                .padding(.bottom, 8)
            Text((try? AttributedString(markdown: "Please download the latest release of the Game Porting Toolkit from [here](https://github.com/Gcenx/game-porting-toolkit/releases/latest)")) ?? AttributedString("Please download the latest release of the Game Porting Toolkit from https://github.com/Gcenx/game-porting-toolkit/releases/latest"))
                .textSelection(.enabled)
                .padding(.bottom, 14)
            HStack(spacing: 20) {
                if inProgress {
                    ProgressView()
                        .controlSize(.large)
                } else {
                    Image(systemName: "document.badge.plus")
                        .font(.system(size: 34))
                }
                Text(inProgress ? "Copying files..." : "Then, drag 'n' drop \"Game Porting Toolkit.app\" here")
                    .font(.system(size: 18, weight: .semibold))
            }
            .foregroundStyle(.secondary)
            .padding(.vertical, 30)
            .padding(.horizontal, 20)
            
            .overlay {
                
                RoundedRectangle(cornerRadius: 20)
                    .strokeBorder(.secondary, style: StrokeStyle(lineWidth: 4, dash: [10]))
            }
            .onDrop(of: ["public.file-url"], delegate: dropDelegate)
        }
        .padding()
    }
}

// partially adapted from https://eclecticlight.co/2024/05/21/swiftui-on-macos-drag-and-drop-and-more/
struct WineDropDelegate: DropDelegate {
    @Binding var inProgress: Bool
    @Binding var showAlert: Bool
    @Binding var alertTitle: String
    @Binding var alertMessage: String
    
    func performDrop(info: DropInfo) -> Bool {
        DispatchQueue.main.async {
            self.inProgress = true
        }
        
        guard let itemProvider = info.itemProviders(for: ["public.file-url"]).first else {
            presentAlert(title: "Error", message: "Could not get dropped item.")
            return false
        }
        
        itemProvider.loadItem(forTypeIdentifier: "public.file-url", options: nil) { (item, error) in
            guard error == nil,
                  let data = item as? Data,
                  let url = URL(dataRepresentation: data, relativeTo: nil) else {
                presentAlert(title: "Error", message: "Could not retrieve file URL from drop.")
                return
            }
            
            DispatchQueue.global(qos: .userInitiated).async {
                self.copyWine(from: url)
            }
        }
        
        return true
    }
    
    private func copyWine(from droppedURL: URL) {
        let fm = FileManager.default
        
        guard droppedURL.lastPathComponent == "Game Porting Toolkit.app" else {
            presentAlert(title: "Wrong Application", message: "Please drop the 'Game Porting Toolkit.app' file, not something else.")
            return
        }
        
        let sourceURL = droppedURL.appendingPathComponent("Contents/Resources/wine", isDirectory: true)
        
        guard fm.fileExists(atPath: sourceURL.path) else {
            presentAlert(title: "Folder Not Found", message: "The 'wine' folder could not be found inside 'Game Porting Toolkit.app'. The app may be corrupted or an incorrect version.")
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
            
            presentAlert(
                title: "Success",
                message: "Wine has been successfully installed to the Application Support directory.",
                success: true
            )
            
        } catch {
            presentAlert(title: "Copy Failed", message: "An error occurred during the copy process: \(error.localizedDescription)")
        }
    }
    
    private func presentAlert(title: String, message: String, success: Bool = false) {
        DispatchQueue.main.async {
            self.alertTitle = title
            self.alertMessage = message
            self.showAlert = true
            self.inProgress = false
            if success {
                Settings.shared.isWineInstalled = true
            }
        }
        
    }
}

#Preview {
    InstallView()
}
