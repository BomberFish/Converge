//
//  AllProgramsView.swift
//  Converge
//
//  Created by Hariz Shirazi on 2025-07-29.
//

import SwiftUI

struct ProgramItem: View {
    public var url: URL
    let image: Image
    init(url: URL) {
        self.url = url
        self.image = peTest(path: url) ?? .init(systemName: "apple.terminal")
    }
    var body: some View {
        HStack {
            image
                .resizable()
                .foregroundStyle(.secondary)
                .frame(maxWidth: 20, maxHeight: 20)
            Text(url.lastPathComponent)
            Spacer()
            Image(systemName: "pin.slash")
                .symbolRenderingMode(.hierarchical)
        }
    }
}

struct AllProgramsView: View {
    public var bottle: Bottle
    @State public var programs: [URL] = []
    var body: some View {
        List {
            Section {
                ForEach(programs, id: \.self) {program in
                    ProgramItem(url: program)
                }
            }.insetGroupedStyle(header: Label("Programs", systemImage: "apple.terminal"))
        }
        .task {
            let searchPaths = [bottle.drive_c.appendingPathComponent("Program Files (x86)"), bottle.drive_c.appendingPathComponent("Program Files")]
            var found: [URL] = []
            let fm = FileManager.default
            for dir in searchPaths {
                if let enumerator = fm.enumerator(at: dir, includingPropertiesForKeys: nil) {
                    for case let fileURL as URL in enumerator {
                        if fileURL.pathExtension.lowercased() == "exe" {
                            found.append(fileURL)
                        }
                    }
                }
            }
            await MainActor.run {
                programs = found
            }
        }
    }
}


// Implemented 100% by hand from version 11 of the PE/COFF spec.
// https://download.microsoft.com/download/9/c/5/9c5b2167-8017-4bae-9fde-d599bac8184a/pecoff.docx
func peTest(path: URL) -> Image? {
    print(path.path(percentEncoded: false))
    guard let data = try? Data(contentsOf: path) else {return nil}
    guard data[0x00..<0x02] == Data([0x4d, 0x5a]) else { // "MZ"
        print("Not a valid executable (expected MZ, got \(data[0x00...0x01] as NSData))")
        return nil
    }
    print("File is an executable")
    let pe_offset = data[0x3c..<(0x3c+4)].withUnsafeBytes {
        $0.load(as: UInt32.self)
    }
    if data[pe_offset..<pe_offset+4] != Data([0x50, 0x45, 0x00, 0x00]) { // "PE\0\0"
        print("Not a PE format executable (expected PE\0\0, got \(data[pe_offset...pe_offset+4] as NSData))");
        return nil
    }
    print("File is a PE format executable")
    let opt_header_size = data[pe_offset+4+16..<pe_offset+4+18].withUnsafeBytes { // SizeOfOptionalHeader
        $0.load(as: UInt8.self)
    }
    print("Optional header is \(opt_header_size) bytes long")
    
    let num_of_sections = data[pe_offset+4+2..<pe_offset+4+2+2].withUnsafeBytes { // NumberOfSections
        $0.load(as: UInt8.self)
    }
    
    print("Executable has \(num_of_sections) sections")
    
    let section_table_offset = pe_offset + 4 // pe magic
                                + 18 + 2 // coff header
                                + UInt32(opt_header_size) // optional coff header
    print("Section table is at offset " + .init(format: "0x%2X", section_table_offset) + " (dec: \(section_table_offset))")
    
    for i in 0..<num_of_sections {
        let start = section_table_offset + (UInt32(i)*40) // section table entries are always exactly 40 bytes long
//        let end = start + 40
        guard let name = String(data: data[start..<start+8], encoding: .utf8) else { // Name (UTF-8 according to spec)
            print("Oh no! Section table parsing went horribly wrong or encountered a noncompliant image!")
            return nil
        }
//        print("Section table entry for \(name) starts at 0x" + String(format: "%2X", start) + " (dec: \(start)) and ends at 0x" + String(format: "%2X", end) + " (dec: \(end))")
        
        let section_size = data[start+16..<start+16+4].withUnsafeBytes { // SizeOfRawData
            $0.load(as: UInt32.self)
        }
        
        let section_start = data[start+20..<start+20+4].withUnsafeBytes { // PointerToRawData
            $0.load(as: UInt32.self)
        }
        
        let section_end = section_start + section_size
        
        print("Section \(name) (\(section_size) bytes long) starts at 0x" + String(format: "%2X", section_start) + " (dec: \(section_start)) and ends at 0x" + String(format: "%2X", section_end) + " (dec: \(section_end))")
        
        if name.contains(".rsrc") {
            print("checking for png start")
            var chunk = Data(count: 0)
            var offset = section_start
            var start = UInt32()
            var found = true
            while chunk != Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]) { // .PNG
                offset += 8
                if offset+8 > data.count {
                    print("sad")
                    found = false
                    break
                }
                chunk = data[offset..<offset+8]
//                print(offset, offset+4, chunk as NSData)
            }
            if found {
                print("found png start at \(offset), checking for end")
                start = offset
                while chunk != Data([0x49, 0x45, 0x4E, 0x44]) { // IEND
                    offset += 4
                    if offset+4 > data.count {
                        print("extra sad")
                        found = false
                        break
                    }
                    chunk = data[offset..<offset+4]
//                    print(offset, offset+4, chunk as NSData)
                }
                
                if found {
                    print("found png end at \(offset+4)")
                    if let img = NSImage(data: data[start...offset]) {
                        return Image(nsImage: img)
                    }
                }
            }
        }
    }
    
    return nil
}

//#Preview {
//    AllProgramsView()
//}
