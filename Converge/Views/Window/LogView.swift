//
//  LogView.swift
//  Converge
//
//  Created by Hariz Shirazi on 2025-06-27.
//

import SwiftUI

struct LogView: View {
    @ObservedObject private var logs = Logs.shared
    private func scroll(_ sc: ScrollViewProxy) {
        if let last = logs.all.last {
            sc.scrollTo(last, anchor: .bottom)
        }
    }
    var body: some View {
        ScrollViewReader {sc in
            ScrollView {
                ForEach(logs.all, id: \.self) { line in
                    Text(line)
                        .textSelection(.enabled)
                        .font(.system(size: 12, weight: .regular, design: .monospaced))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(
                            logs.standardError.contains(line) ? Color.red.opacity(0.1) : Color.clear)
                        .cornerRadius(18)
                        .tag(line)
//                        .padding(.vertical, 2)
                }
            }
            .onChange(of: logs.all) {
                scroll(sc)
            }
            .onAppear {
                scroll(sc)
            }
            .padding()
        }
    }
}

class Logs: @unchecked Sendable, ObservableObject {
    static let shared = Logs()
    
    init() {
        stdout.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }
            
            if let line = String(data: data, encoding: .utf8) {
                DispatchQueue.main.async {
                    self.standardOutput.append(line)
                    self.all.append(line)
                }
            }
        }
        stderr.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }
            
            if let line = String(data: data, encoding: .utf8) {
                DispatchQueue.main.async {
                    self.standardError.append(line)
                    self.all.append(line)
                }
            }
        }
    }
    
    @Published private(set) var all: [String] = []
    @Published private(set) var standardOutput: [String] = []
    @Published private(set) var standardError: [String] = []
}

#Preview {
    LogView()
}
