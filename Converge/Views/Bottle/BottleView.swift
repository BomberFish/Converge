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
    @State var steamExists = false
    var body: some View {
        let steamPath = bottle.drive_c.appendingPathComponent("Program Files (x86)/Steam/steam.exe")
        VStack {
            List {
                Section {
                    NavigationLink(destination: AllProgramsView(bottle: bottle)) {
                        HStack {
                            Label("All Programs", systemImage: "square.grid.3x3")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundStyle(.secondary)
                        }
                    }
                }.insetGroupedStyle(header: Label("Quick Launch", systemImage: "arrow.up.right.circle"))
                
                // https://docs.getwhisky.app/steam.html
                if steamExists {
                    Section {
                        Group {
                            Button("Fix Steam") {
                                Task {
                                    try? await WineRunner.runWine(cmdline: [steamPath.path(percentEncoded: false), "-forcesteamupdate", "-forcepackagedownload", "-overridepackageurl", "http://web.archive.org/web/20250306194830if_/media.steampowered.com/client", "-exitsteam"], bottle: bottle)
                                }
                            }
                            .buttonStyle(.bordered)
//                            #if DEBUG
//                            Group {
//                                Button("Run Steam but broken") {
//                                    Task {
//                                        try? await WineRunner.runWine(cmdline: [steamPath.path(percentEncoded: false)], bottle: bottle)
//                                    }
//                                }
//                                //--no-sandbox --in-process-gpu --disable-gpu
//                                Button("Run Steam but less broken") {
//                                    Task {
//                                        try? await WineRunner.runWine(cmdline: [steamPath.path(percentEncoded: false), "-no-sandbox", "-in-process-gpu", "-disable-gpu", "-no-cef-sandbox"], bottle: bottle)
//                                    }
//                                }
//                            }
//                            .buttonStyle(.borderedProminent)
//                            #endif
                            Button("Run Steam") {
                                Task {
                                    try? await WineRunner.runWine(cmdline: [steamPath.path(percentEncoded: false), "-noverifyfiles", "-nobootstrapupdate", "-skipinitialbootstrap", "-norepairfiles", "-overridepackageurl"], bottle: bottle)
                                }
                            }
                            .buttonStyle(.borderedProminent)
                        }
                        .controlSize(.large)
                        .frame(maxWidth: .infinity)
                    }.insetGroupedStyle(header: Label("Steam", systemImage: "gamecontroller"))
                }
                Section {
                    NavigationLink(destination: BottleSettingsView(bottle: bottle)) {
                        HStack {
                            Label("Bottle Configuration", systemImage: "gearshape.2")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundStyle(.secondary)
                        }
                    }
                }.insetGroupedStyle(header: Label("Configuration", systemImage: "gear"))
            }
            
            HStack {
                Spacer()
                Button("Open C: Drive", systemImage: "internaldrive") {
                    NSWorkspace.shared.open(bottle.drive_c)
                }
                Button("Run .exe", systemImage: "apple.terminal") {
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
        .onAppear {
            steamExists = FileManager.default.fileExists(atPath: steamPath.path(percentEncoded: false))
        }
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
