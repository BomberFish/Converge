//
//  EnvironmentView.swift
//  Converge
//
//  Created by Hariz Shirazi on 2025-06-27.
//

import SwiftUI

struct EnvironmentView: View {
    public var bottle: Bottle
    @ObservedObject var mgr = BottleManager.shared
    var body: some View {
        VStack {
            List {
                Section {
                    EnvSwitch(label: "ESync", variable: "WINEESYNC", bottle: bottle)
                }.insetGroupedStyle(header: Label("Wine", systemImage: "wineglass"))
                
                Section {
                    EnvSwitch(label: "Metal HUD", variable: "MTL_HUD_ENABLED", bottle: bottle)
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
            HStack {
                Spacer()
                Button("Run winecfg") {
                    Task(priority: .background) {
                        try? await WineRunner.runWine(cmdline: "winecfg", bottle: bottle)
                    }
                }
            }
        }
        .padding()
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
                .textFieldStyle(.plain)
                .onChange(of: focused) {
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
