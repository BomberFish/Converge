//
//  BottleView.swift
//  Converge
//
//  Created by Hariz Shirazi on 2025-06-27.
//

import SwiftUI

struct BottleView: View {
    public var bottle: Bottle
    @State private var showExeImporter: Bool = false
    var body: some View {
        VStack {
            List {
                Section {
                    NavigationLink(destination: BottleSettingsView(bottle: bottle)) {
                        HStack {
                            Label("Bottle Configuration", systemImage: "gearshape.2")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundStyle(.secondary)
                        }
                    }
                }.insetGroupedStyle(header: Text("Configuration"))
            }
            
            HStack {
                Spacer()
                Button("Open C: Drive") {
                    NSWorkspace.shared.open(bottle.path.appendingPathComponent("drive_c"))
                }
                Button("Run .exe") {
                    showExeImporter.toggle()
                }
            }
        }
        .navigationTitle(bottle.name)
        .padding()
        .fileImporter(isPresented: $showExeImporter, allowedContentTypes: [.init(filenameExtension: "exe"), .init(filenameExtension: "bat")].map({$0 ?? .item}), onCompletion: {res in
            switch res {
            case .success(let url):
                Task (priority: .background) {
                    try? await WineRunner.runWine(cmdline: [url.path], bottle: bottle)
                }
            case .failure(let error):
                print("Error running file: \(error.localizedDescription)")
            }
        })
//        .navigationTitle(bottle.name)
    }
}

extension View {
    func insetGroupedStyle<V: View>(header: V = EmptyView() as! V, footer: String? = nil) -> some View {
        VStack(alignment: .leading) {
            GroupBox(label: HStack{header}.font(.headline).foregroundStyle(.secondary).padding(.top).padding(.bottom, 6)) {
                VStack {
                    self.padding(.vertical, 3)
                }.padding(.horizontal).padding(.vertical)
            }
            if let footer = footer {
                Text(footer)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
            }
        }
    }
}

//#Preview {
//    BottleView()
//}
