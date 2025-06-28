//
//  WineRunner.swift
//  Converge
//
//  Created by Hariz Shirazi on 2025-06-26.
//

import Foundation

fileprivate let PATH = URL.applicationSupportDirectory.appendingPathComponent("Converge/wine/bin", isDirectory: true)
struct WineRunner {
    static func runCommand(executable: URL, cmdline: String, env: [String: String] = [:], bottle: Bottle? = nil, wait: Bool) async throws {
        var env = env
        let task = Process()
        task.executableURL = executable
        env["PATH"] = PATH.path
        if let bottle {
            env["WINEPREFIX"] = bottle.path.path
        }
        
        if let envPlist = bottle?.environmentPath,
           FileManager.default.fileExists(atPath: envPlist.path) {
            if let plistData = try? Data(contentsOf: envPlist),
               let plistEnv = try? PropertyListSerialization.propertyList(from: plistData, options: [], format: nil) as? [String: String] {
#if DEBUG
                print("loaded env overrides: \(plistEnv)")
#endif
                env.merge(plistEnv) { (_, new) in new }
            }
        }
        
        let envVars = ProcessInfo.processInfo.environment.merging(env) { (_, new) in new }
        task.environment = envVars
        
        task.arguments = [cmdline]
        
        print("Running command: \(executable.path) with arguments: \(task.arguments ?? [])")
        print("Environment Variables: \(envVars)")
        
        try task.run()
        if wait {
            task.waitUntilExit()
        } else {
            task.terminationHandler = { _ in
                print("Wine command finished.")
            }
        }
    }
    
    static func runWine(cmdline: String, bottle: Bottle? = nil, wait: Bool = false) async throws {
        let wineExecutable = PATH.appendingPathComponent("wine64", isDirectory: false)
        try await runCommand(executable: wineExecutable, cmdline: cmdline, bottle: bottle, wait: wait)
    }
}


struct Bottle: Identifiable, Hashable, Codable {
    var id: UUID = UUID()
    var name: String
    var path: URL {
        URL.applicationSupportDirectory.appendingPathComponent("Converge/Bottles/\(name)", isDirectory: true)
    }
    var environmentPath: URL {
        URL.applicationSupportDirectory.appendingPathComponent("Converge/Bottles/\(name)/Environment.plist", isDirectory: false)
    }
}

class BottleManager: ObservableObject {
    @Published var bottles: [Bottle] = BottleManager.all()
    public static let shared = BottleManager()
    
    /// Creates a new bottle with the given name.
    public func create(name: String) -> Bottle {
        let bottle = Bottle(name: name)
        do {
            try FileManager.default.createDirectory(at: bottle.path, withIntermediateDirectories: true)
            // write a blank plist to the env file
            try PropertyListSerialization.data(fromPropertyList: [:], format: .xml, options: 0).write(to: bottle.environmentPath)
        } catch {
            print("Error creating bottle directory: \(error.localizedDescription)")
        }
        bottles.append(bottle)
        return bottle
    }
    
    /// Returns all bottles from the application support directory.
    private static func all() -> [Bottle] {
        let fm = FileManager.default
        let bottlesDir = URL.applicationSupportDirectory.appendingPathComponent("Converge/Bottles", isDirectory: true)
        
        guard let contents = try? fm.contentsOfDirectory(at: bottlesDir, includingPropertiesForKeys: nil) else {
            return []
        }
        
        return contents.compactMap { url in
            guard let name = url.lastPathComponent.removingPercentEncoding else { return nil }
            return Bottle(name: name)
        }
    }
    
    /// Deletes the specified bottle and its associated files.
    func delete(_ bottle: Bottle) async throws {
        try? await WineRunner.runWine(cmdline: "wineboot --shutdown", bottle: bottle, wait: true)
        
        try FileManager.default.removeItem(at: bottle.path)
        bottles.removeAll { $0.id == bottle.id }
    }
    
    /// Sets the environment variables for the specified bottle.
    func setEnvironment(for bottle: Bottle, env: [String: String]) throws {
        var currentEnv: [String: String] = [:]
        if FileManager.default.fileExists(atPath: bottle.environmentPath.path) {
            if let plistData = try? Data(contentsOf: bottle.environmentPath),
               let plistEnv = try? PropertyListSerialization.propertyList(from: plistData, options: [], format: nil) as? [String: String] {
                currentEnv = plistEnv
            }
        }
        
        currentEnv.merge(env) { (_, new) in new }
        
        let data = try PropertyListSerialization.data(fromPropertyList: currentEnv, format: .xml, options: 0)
        try data.write(to: bottle.environmentPath)
    }
    
    /// Adds an environment variable to the specified bottle.
    func addEnvironmentVariable(_ key: String, value: String, to bottle: Bottle) throws {
        try setEnvironment(for: bottle, env: [key: value])
    }
    
    /// Retrieves the environment variables for the specified bottle.
    func getEnvironment(for bottle: Bottle) -> [String: String] {
        guard FileManager.default.fileExists(atPath: bottle.environmentPath.path) else {
            return [:]
        }
        
        if let plistData = try? Data(contentsOf: bottle.environmentPath),
           let plistEnv = try? PropertyListSerialization.propertyList(from: plistData, options: [], format: nil) as? [String: String] {
            return plistEnv
        }
        
        return [:]
    }
    
    /// Retrieves a specific environment variable for the specified bottle.
    func getEnvironmentVariable(_ key: String, for bottle: Bottle) -> String? {
        getEnvironment(for: bottle)[key]
    }
}
