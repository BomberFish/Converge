//
//  EnvironmentView.swift
//  Converge
//
//  Created by Hariz Shirazi on 2025-06-27.
//

import SwiftUI

struct BottleSettingsView: View {
    public var bottle: Bottle
    @ObservedObject var mgr = BottleManager.shared
    
    @State var retinaOn: Bool = false
    
    @State var build: String = ""
    @FocusState private var versionFocused: Bool
    
    @State var version: String = "10.0"
    
    // whether we are currently accessing or editing the registry. prevents race conditions
    @State var preventingRegistryRacism: Bool = true

    var body: some View {
        VStack {
            List {
                Group {
                    Section {
                        HStack {
                            Text("Windows Version")
                            Spacer()
                            Picker("Version", selection: $version) {
                                Text("Windows 10/11").tag("10.0")
                                Text("Windows 8.1").tag("6.3")
                                Text("Windows 8").tag("6.2")
                                Text("Windows 7").tag("6.1")
                                Text("Windows Vista").tag("6.0")
                                Text("Windows XP").tag("5.1")
                                Text("Windows 2000").tag("5.0")
                            }
                        }
                        .pickerStyle(.menu)
                        .labelsHidden()
                        .disabled(preventingRegistryRacism)
                        .onChange(of: version) {
                            Task { @MainActor in
                                preventingRegistryRacism = true
                                try? await BottleManager.shared.setRegistryValue(
                                    "HKLM\\Software\\Microsoft\\Windows NT\\CurrentVersion",
                                    name: "CurrentVersion",
                                    value: version,
                                    type: .string,
                                    bottle: bottle
                                )
                                try? await BottleManager.shared.setRegistryValue(
                                    "HKLM\\Software\\Microsoft\\Windows NT\\CurrentVersion",
                                    name: "CurrentMajorVersionNumber",
                                    value: String(version.split(separator: ".").first ?? ""),
                                    type: .dword,
                                    bottle: bottle
                                )
                                try? await BottleManager.shared.setRegistryValue(
                                    "HKLM\\Software\\Microsoft\\Windows NT\\CurrentVersion",
                                    name: "CurrentMinorVersionNumber",
                                    value: String(version.split(separator: ".").last ?? ""),
                                    type: .dword,
                                    bottle: bottle
                                )
                                preventingRegistryRacism = false
                            }
                        }
                        
                        HStack {
                            Text("Build Number")
                            Spacer()
                            TextField("Version", text: $build)
                                .focused($versionFocused)
                                .frame(width: 100)
                                .textFieldStyle(.squareBorder)
                        }
                        .onChange(of: versionFocused) {
                            if versionFocused { return }
                            Task { @MainActor in
                                preventingRegistryRacism = true
                                try? await BottleManager.shared.setRegistryValue(
                                    "HKLM\\Software\\Microsoft\\Windows NT\\CurrentVersion",
                                    name: "CurrentBuild",
                                    value: build,
                                    type: .string,
                                    bottle: bottle
                                )
                                try? await BottleManager.shared.setRegistryValue(
                                    "HKLM\\Software\\Microsoft\\Windows NT\\CurrentVersion",
                                    name: "CurrentBuildNumber",
                                    value: build,
                                    type: .string,
                                    bottle: bottle
                                )
                                preventingRegistryRacism = false
                            }
                        }
                        EnvSwitch(label: "ESync", variable: "WINEESYNC", bottle: bottle)
                    }.insetGroupedStyle(header: Label("Wine", systemImage: "wineglass"))
                    
                    Section {
                        EnvSwitch(label: "Metal HUD", variable: "MTL_HUD_ENABLED", bottle: bottle)
                        HStack {
                            Text("Retina Mode")
                            Spacer()
                            Toggle("Retina Mode", isOn: $retinaOn)
                                .onChange(of: retinaOn) {
                                    if preventingRegistryRacism { return }
                                    Task {@MainActor in
                                        preventingRegistryRacism = true
                                        try? await BottleManager.shared.setRegistryValue(
                                            "HKCU\\Software\\Wine\\Mac Driver",
                                            name: "RetinaMode",
                                            value: retinaOn ? "y" : "n",
                                            type: .string,
                                            bottle: bottle
                                        )
                                        preventingRegistryRacism = false
                                    }
                                }
                                .toggleStyle(.switch)
                                .labelsHidden()
                                .disabled(preventingRegistryRacism)
                        }
                    }.insetGroupedStyle(header: Label("Graphics", systemImage: "display"))
#if arch(arm64)
                    Section {
                        if let device = MTLCreateSystemDefaultDevice(), device.supportsRaytracing {
                            EnvSwitch(label: "DirectX Raytracing", variable: "D3DM_SUPPORT_DXR", bottle: bottle)
                        }
                        EnvSwitch(label: "Advertise AVX support", variable: "ROSETTA_ADVERTISE_AVX", bottle: bottle)
                    }.insetGroupedStyle(header: Label("Apple Silicon", systemImage: "cpu"))
#endif
                }
            }
            HStack {
                Spacer()
                Button("Registry Editor") {
                    Task(priority: .background) {
                        try? await WineRunner.runWine(
                            cmdline: ["regedit"],
                            bottle: bottle
                        )
                    }
                }
                Button("Run winecfg") {
                    Task(priority: .background) {
                        try? await WineRunner.runWine(cmdline: ["winecfg"], bottle: bottle)
                    }
                }
            }
        }
        .padding()
        .task {
            retinaOn = (try? await BottleManager.shared.getRegistryValue(
                "HKCU\\Software\\Wine\\Mac Driver",
                name: "RetinaMode", type: .string,
                bottle: bottle
            ) ?? "n") == "y"
            try? await Task.sleep(for: .milliseconds(100)) // give the UI a chance to update
            build = (try? await BottleManager.shared.getRegistryValue(
                "HKLM\\Software\\Microsoft\\Windows NT\\CurrentVersion",
                name: "CurrentBuild",
                type: .string,
                bottle: bottle
            )) ?? ""
            try? await Task.sleep(for: .milliseconds(100))
            version = (try? await BottleManager.shared.getRegistryValue(
                "HKLM\\Software\\Microsoft\\Windows NT\\CurrentVersion",
                name: "CurrentVersion",
                type: .string,
                bottle: bottle
            )) ?? "10.0"
            try? await Task.sleep(for: .milliseconds(100))
            preventingRegistryRacism = false
        }
    }
}

struct EnvSwitch: View {
    public var label: String
    public var variable: String
    public var bottle: Bottle
    @State private var isOn: Bool
    
    init(label: String, variable: String, bottle: Bottle) {
        self.label = label
        self.variable = variable
        self.bottle = bottle
        
        self._isOn = .init(initialValue: BottleManager.shared.getEnvironmentVariable(variable, for: bottle) == "1")
    }
    
    var body: some View {
        HStack {
            Text(label)
            Spacer()
            Toggle("\(label)", isOn: $isOn)
                .toggleStyle(.switch)
                .labelsHidden()
        }
            .onChange(of: isOn) {
                try? BottleManager.shared.addEnvironmentVariable(
                    variable,
                    value: isOn ? "1" : "0",
                    to: bottle
                )
                
                isOn = BottleManager.shared.getEnvironmentVariable(variable, for: bottle) == "1"
            }
    }
}


struct EnvTextField: View {
    public var label: String
    public var variable: String
    public var bottle: Bottle
    @State private var value: String
    
    @FocusState private var focused: Bool
    
    init(label: String, variable: String, bottle: Bottle, value: String) {
        self.label = label
        self.variable = variable
        self.bottle = bottle
        self._value = .init(initialValue: value)
    }
    
    var body: some View {
        HStack {
            Text(label)
            Spacer()
            TextField("Value", text: $value)
                .focused($focused)
                .textFieldStyle(.squareBorder)
                .onChange(of: focused) {
                    if focused { return }
                    try? BottleManager.shared.addEnvironmentVariable(
                        variable,
                        value: value,
                        to: bottle
                    )
                    
                    value = BottleManager.shared.getEnvironmentVariable(variable, for: bottle) ?? ""
                }
        }
    }
}


//#Preview {
//    EnvironmentView()
//}
