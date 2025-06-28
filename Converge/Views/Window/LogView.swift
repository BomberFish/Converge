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
            withAnimation(.easeInOut(duration: 0.1)) {
                sc.scrollTo(last.id, anchor: .bottom)
            }
        }
    }
    var body: some View {
        ScrollViewReader { sc in
            ScrollView {
                ForEach(logs.all) { line in
                    Text(line.message)
                        .textSelection(.enabled)
                        .font(.system(size: 12, weight: .regular, design: .monospaced))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(
                            line.type == .error ? Color.red.opacity(0.1) : Color.clear)
                        .cornerRadius(18)
                        .tag(line.id) 
                }
                .padding(.horizontal)
                .padding(.bottom)
            }
            .onChange(of: logs.all) { _ in
                DispatchQueue.main.async { scroll(sc) }
            }
            .onAppear {
                DispatchQueue.main.async { scroll(sc) }
            }
        }
    }
}

class Logs: @unchecked Sendable, ObservableObject {
    static let shared = Logs()
    
    struct Log: Identifiable, Equatable, Hashable {
        var id: String { date }
        let date: String
        let message: String
        let type: LogType
        
        enum LogType {
            case regular,error
        }
        
        init(_ message: String, type: LogType = .regular) {
            self.date = Date().description
            self.message = message
            self.type = type
        }
    }
    
    init() {
        stdout.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }
            
            if let line = String(data: data, encoding: .utf8) {
                DispatchQueue.main.async {
                    self.all.append(.init(line))
                }
            }
        }
        stderr.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }
            
            if let line = String(data: data, encoding: .utf8) {
                DispatchQueue.main.async {
                    self.all.append(.init(line, type: .error))
                }
            }
        }
    }
    
    @Published private(set) var all: [Log] = []
}

#Preview {
    LogView()
}
