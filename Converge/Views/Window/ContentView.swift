//
//  ContentView.swift
//  Converge
//
//  Created by Hariz Shirazi on 2025-06-26.
//

import SwiftUI


struct BottleListView: View {
    public var bottle: Bottle
    @ObservedObject var bottleMgr = BottleManager.shared
    @Binding var selectedBottle: Bottle?
    @State var deletionInProgress: Bool = false
    
    var body: some View {
        NavigationLink(value: bottle) {
            HStack {
                if deletionInProgress {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Image(systemName: "wineglass")
                }
                Text(bottle.name)
                    .lineLimit(1)
            }
            .contextMenu {
                Button("Delete Bottle") {
                    deletionInProgress = true
                    Task {
                        do {try await bottleMgr.delete(bottle)} catch {print("Failed to delete bottle: \(error.localizedDescription)")}
                    }
                    selectedBottle = nil
                }
            }
        }
    }
}

struct ContentView: View {
    @ObservedObject var bottleMgr = BottleManager.shared
    @State var selectedBottle: Bottle? = nil
    @State var showCreationSheet = false
    @State private var newBottleName = ""
    @State var showLogs = true
    
    @State var runCfgImmediately = false
    
    @ViewBuilder var sheet: some View {
        VStack {
            Text("Create a new bottle")
                .font(.title)
            TextField("Bottle Name", text: $newBottleName)
                .textFieldStyle(.roundedBorder)
                .padding()
            Toggle("Run configuration after creation", isOn: $runCfgImmediately)
                .padding()
            HStack {
                Spacer()
                Button("Cancel", role: .cancel) {
                    showCreationSheet = false
                }
                
                Group {
                    if #available(macOS 16.0, *) {
                        Button("Create", role: .confirm, action: create)
                    } else {
                        Button("Create", action: create)
                    }
                }
                .disabled(newBottleName.isEmpty || bottleMgr.bottles.contains(where: { $0.name == newBottleName }))
            }
        }
        .padding()
    }
    
    var body: some View {
        NavigationSplitView(sidebar: {
            List(selection: $selectedBottle) {
                ForEach(bottleMgr.bottles) { bottle in
                    BottleListView(bottle: bottle, selectedBottle: $selectedBottle)
                        .tag(bottle)
                }
            }
        }, detail: {
            ZStack {
                if let selectedBottle {
                    NavigationStack {
                        BottleView(bottle: selectedBottle)
                    }
                } else {
                    VStack {
                        Text("Welcome to Converge!")
                            .font(.title.weight(.bold))
                        Text(bottleMgr.bottles.isEmpty ? "Create a bottle to get started." : "Select a bottle from the sidebar to get started.")
                            .padding()
                    }
                }
            }
        })
        .sheet(isPresented: $showCreationSheet) {
            sheet
        }
        .inspector(isPresented: $showLogs) {
            LogView()
                .inspectorColumnWidth(min: 360, ideal: 600, max: 2000)
        }
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Button(action: {
                    showCreationSheet = true
                }) {
                    Label("Create Bottle", systemImage: "plus")
                }
            }
            ToolbarItem(placement: .automatic) {
                Button(action: {
                    showLogs.toggle()
                }) {
                    Label("Show Logs", systemImage: "doc.text")
                }
            }
        }
    }
    
    func create() {
        selectedBottle = bottleMgr.create(name: newBottleName)
        showCreationSheet = false
        if runCfgImmediately {
            Task(priority: .background) {
                try? await WineRunner.runWine(cmdline: "winecfg", bottle: selectedBottle)
            }
        }
    }
}

#Preview {
    ContentView()
}
