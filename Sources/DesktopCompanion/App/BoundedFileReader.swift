import Foundation

enum BoundedFileReaderError: Error, Equatable {
    case fileTooLarge
}

enum BoundedFileReader {
    static func data(from url: URL, maxBytes: UInt64, fileManager: FileManager = .default) throws -> Data {
        guard maxBytes < UInt64(Int.max) else {
            throw BoundedFileReaderError.fileTooLarge
        }

        if let fileSize = try? fileManager.attributesOfItem(atPath: url.path)[.size] as? NSNumber,
           fileSize.uint64Value > maxBytes {
            throw BoundedFileReaderError.fileTooLarge
        }

        let fileHandle = try FileHandle(forReadingFrom: url)
        defer {
            try? fileHandle.close()
        }

        let data = try fileHandle.read(upToCount: Int(maxBytes) + 1) ?? Data()
        guard data.count <= Int(maxBytes) else {
            throw BoundedFileReaderError.fileTooLarge
        }

        return data
    }
}
