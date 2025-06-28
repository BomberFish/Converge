//
//  main.swift
//  Converge
//
//  Created by Hariz Shirazi on 2025-06-27.
//
print("main")

import Foundation

var stdin = Pipe()
dup2(stdin.fileHandleForWriting.fileDescriptor, STDIN_FILENO)
var stdout = Pipe()
dup2(stdout.fileHandleForWriting.fileDescriptor, STDOUT_FILENO)
var stderr = Pipe()
dup2(stderr.fileHandleForWriting.fileDescriptor, STDERR_FILENO)
print("Welcome to Converge :3")

var modelIdentifier: String {
    let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("IOPlatformExpertDevice"))
    defer {IOObjectRelease(service)}
    if let modelData = IORegistryEntryCreateCFProperty(service, "model" as CFString, kCFAllocatorDefault, 0).takeRetainedValue() as? Data {
        if let modelIdentifierCString = String(data: modelData, encoding: .utf8)?.cString(using: .utf8) {
            return String(cString: modelIdentifierCString)
        }
    }
    return "Unknown"
}

var processorName: String {
    var size: size_t = 0
    sysctlbyname("machdep.cpu.brand_string", nil, &size, nil, 0)
    var name = [CChar](repeating: 0, count: Int(size))
    sysctlbyname("machdep.cpu.brand_string", &name, &size, nil, 0)
    return String(cString: name)
}

print("""

OS: \(ProcessInfo.processInfo.operatingSystemVersionString)
Mac: \(modelIdentifier)
Processor: \(ProcessInfo.processInfo.processorCount)x \(processorName)
""")

ConvergeApp.main()
