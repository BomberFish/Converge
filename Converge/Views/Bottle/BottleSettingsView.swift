//
//  EnvironmentView.swift
//  Converge
//
//  Created by Hariz Shirazi on 2025-06-27.
//

import SwiftUI

struct Version: Identifiable, Hashable {
    var id: String { version + "." + build }
    var name: String
    var version: String
    var build: String
}

let versions: [Version] = [
    .init(name: "Windows 11", version: "10.0", build: "22000"),
    .init(name: "Windows 10", version: "10.0", build: "19045"),
    .init(name: "Windows 8.1", version: "6.3", build: "9600"),
    .init(name: "Windows 8", version: "6.2", build: "9200"),
    .init(name: "Windows 7", version: "6.1", build: "7601"),
    .init(name: "Windows Vista", version: "6.0", build: "6002"),
    .init(name: "Windows XP", version: "5.1", build: "2600"),
    .init(name: "Windows 2000", version: "5.0", build: "2195")
]

struct BottleSettingsView: View {
    public var bottle: Bottle
    @ObservedObject var mgr = BottleManager.shared
    
    @State var retinaOn: Bool = false
    @State var metalFxOn: Bool = false
    @State var debugOn: Bool = false
    
    @State var build: String = ""
    @FocusState private var versionFocused: Bool
    
    @State var version: Version = versions[0]
    
    
    // whether we are currently accessing or editing the registry. prevents race conditions
    @State var preventingRegistryRacism: Bool = true

    var body: some View {
        VStack {
            List {
                Group {
                    Section {
                        HStack {
                            Label("Windows Version", systemImage: "pc")
                            Spacer()
                            Picker("Version", selection: $version) {
                                ForEach(versions, id: \.self) { ver in
                                    Text(ver.name).tag(ver)
                                }
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
                                    value: version.version,
                                    type: .string,
                                    bottle: bottle
                                )
                                try? await BottleManager.shared.setRegistryValue(
                                    "HKLM\\Software\\Microsoft\\Windows NT\\CurrentVersion",
                                    name: "CurrentMajorVersionNumber",
                                    value: String(version.version.split(separator: ".").first ?? ""),
                                    type: .dword,
                                    bottle: bottle
                                )
                                try? await BottleManager.shared.setRegistryValue(
                                    "HKLM\\Software\\Microsoft\\Windows NT\\CurrentVersion",
                                    name: "CurrentMinorVersionNumber",
                                    value: String(version.version.split(separator: ".").last ?? ""),
                                    type: .dword,
                                    bottle: bottle
                                )
                                try? await BottleManager.shared.setRegistryValue(
                                    "HKLM\\Software\\Microsoft\\Windows NT\\CurrentVersion",
                                    name: "CurrentBuild",
                                    value: version.build,
                                    type: .string,
                                    bottle: bottle
                                )
                                build = version.build
                                preventingRegistryRacism = false
                            }
                        }
                        
                        HStack {
                            Label("Build Number", systemImage: "apple.terminal")
                            Spacer()
                            TextField("Version", text: $build)
                                .focused($versionFocused)
                                .frame(width: 100)
                                .textFieldStyle(.squareBorder)
                                .disabled(preventingRegistryRacism)
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
                        EnvSwitch(label: "ESync", systemImage: "arrow.trianglehead.2.clockwise.rotate.90", variable: "WINEESYNC", bottle: bottle)
                        HStack {
                            Label("Verbose Logging (Impacts Performance)", systemImage: "ant")
                            Spacer()
                            Toggle("Verbose Logging", isOn: $debugOn)
                                .onChange(of: debugOn) {
                                    try? BottleManager.shared.addEnvironmentVariable(
                                        "WINEDEBUG",
                                        value: debugOn ? "+all" : "-all",
                                        to: bottle
                                    )
                                    debugOn = BottleManager.shared.getEnvironmentVariable("WINEDEBUG", for: bottle) == "+all"
                                }
                                .toggleStyle(.switch)
                                .labelsHidden()
                        }
                    }.insetGroupedStyle(header: Label("Wine", systemImage: "wineglass"))
                    
                    Section {
                        EnvSwitch(label: "Metal HUD", systemImage: "ecg.text.page", variable: "MTL_HUD_ENABLED", bottle: bottle)
                        HStack {
                            Label("Retina Mode", systemImage: "eye")
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
                            EnvSwitch(label: "DirectX Raytracing", systemImage: "circle.lefthalf.filled.righthalf.striped.horizontal", variable: "D3DM_SUPPORT_DXR", bottle: bottle)
                        }
                        if #available(macOS 16.0, *) {
                            HStack {
                                Label("DLSS", systemImage: "sparkles.2")
                                Spacer()
                                Toggle("DLSS", isOn: $metalFxOn)
                                    .onChange(of: metalFxOn) {
                                        try? BottleManager.shared.addEnvironmentVariable(
                                            "D3DM_ENABLE_METALFX",
                                            value: metalFxOn ? "1" : "0",
                                            to: bottle
                                        )
                                        try? BottleManager.shared.addDllOverride(
                                            name: "nvngx",
                                            to: bottle
                                        )
                                        try? BottleManager.shared.addDllOverride(
                                            name: "nvapi64",
                                            to: bottle
                                        )
                                        metalFxOn = (BottleManager.shared.getEnvironmentVariable(
                                            "D3DM_ENABLE_METALFX", for: bottle) == "1") || ((BottleManager.shared.getDllOverrides(for: bottle)).contains(where: {$0 == "nvngx" || $0 == "nvapi64"}))
                                    }
                                    .toggleStyle(.switch)
                                    .labelsHidden()
                            }
                        }
                        EnvSwitch(label: "Advertise AVX support", systemImage: "cpu", variable: "ROSETTA_ADVERTISE_AVX", bottle: bottle)
                    }.insetGroupedStyle(header: Label("Apple Silicon", systemImage: "cpu"))
#endif
                }
            }
            HStack {
                Spacer()
                Button("Registry Editor", systemImage: "squareshape.split.2x2") {
                    Task(priority: .background) {
                        try? await WineRunner.runWine(
                            cmdline: ["regedit"],
                            bottle: bottle
                        )
                    }
                }
                Button("Run winecfg", systemImage: "wineglass") {
                    Task(priority: .background) {
                        try? await WineRunner.runWine(cmdline: ["winecfg"], bottle: bottle)
                    }
                }
            }
        }
        .padding()
        .task {
            metalFxOn = BottleManager.shared.getEnvironmentVariable(
                "D3DM_ENABLE_METALFX", for: bottle) == "1" || (BottleManager.shared.getDllOverrides(for: bottle)).contains(where: {$0 == "nvngx" || $0 == "nvapi64"})
            debugOn = BottleManager.shared.getEnvironmentVariable("WINEDEBUG", for: bottle) == "+all"
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
            let kernelVer = (try? await BottleManager.shared.getRegistryValue(
                "HKLM\\Software\\Microsoft\\Windows NT\\CurrentVersion",
                name: "CurrentVersion",
                type: .string,
                bottle: bottle
            )) ?? "10.0"
            if kernelVer == "10.0" && Double(build) ?? 0.0 >= 22000 {
                version = versions[0]
            } else {
                version = versions.first(where: { $0.version == kernelVer }) ?? versions[0]
            }
            try? await Task.sleep(for: .milliseconds(100))
            preventingRegistryRacism = false
        }
    }
}

struct EnvSwitch: View {
    public var label: String
    public var systemImage: String
    public var variable: String
    public var bottle: Bottle
    @State private var isOn: Bool
    
    init(label: String, systemImage: String, variable: String, bottle: Bottle) {
        self.label = label
        self.variable = variable
        self.bottle = bottle
        self.systemImage = systemImage
        self._isOn = .init(initialValue: BottleManager.shared.getEnvironmentVariable(variable, for: bottle) == "1")
    }
    
    var body: some View {
        HStack {
            Label(label, systemImage: systemImage)
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
    public var systemImage: String
    public var variable: String
    public var bottle: Bottle
    @State private var value: String
    
    @FocusState private var focused: Bool
    
    init(label: String, systemImage: String, variable: String, bottle: Bottle, value: String) {
        self.label = label
        self.variable = variable
        self.bottle = bottle
        self.systemImage = systemImage
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
