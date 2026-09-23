import Foundation

/// Why a saved document cannot be used (Decision #28). Never includes snippet text.
public enum CorruptReason: Equatable, Sendable {
    case unreadable
    case invalid(String)
    case newerSchema(Int)
}

public enum LoadResult: Equatable, Sendable {
    case notFound
    case loaded(ConfigDocument)
    case corrupt(CorruptReason)
}

/// JSON encoding of the configuration document, schema version 1.
public enum ConfigCodec {
    public static func encode(_ document: ConfigDocument) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(document)
    }

    public static func decode(_ data: Data) -> LoadResult {
        guard !data.isEmpty,
              let object = try? JSONSerialization.jsonObject(with: data),
              let dictionary = object as? [String: Any] else {
            return .corrupt(.unreadable)
        }
        guard let version = dictionary["schemaVersion"] as? Int else {
            return .corrupt(.invalid("missing schemaVersion"))
        }
        if version > ConfigDocument.currentSchemaVersion { return .corrupt(.newerSchema(version)) }
        if version < 1 { return .corrupt(.invalid("unknown schemaVersion")) }
        if version == ConfigDocument.currentSchemaVersion, let key = unknownKey(in: dictionary) {
            // A field this version does not know would be lost on the next save.
            return .corrupt(.invalid("unknown field \(key)"))
        }
        let migrated: Data
        do {
            migrated = try migrate(data, from: version)
        } catch {
            return .corrupt(.invalid("migration failed"))
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        var document: ConfigDocument
        do {
            document = try decoder.decode(ConfigDocument.self, from: migrated)
        } catch let DecodingError.keyNotFound(key, _) {
            return .corrupt(.invalid("missing field \(key.stringValue)"))
        } catch let DecodingError.dataCorrupted(context) {
            return .corrupt(.invalid("bad value at \(context.codingPath.map(\.stringValue).joined(separator: "."))"))
        } catch {
            return .corrupt(.invalid("wrong field type"))
        }
        if let problem = validationProblem(document) { return .corrupt(.invalid(problem)) }
        document.preferences = document.preferences.clamped()
        document.schemaVersion = ConfigDocument.currentSchemaVersion
        return .loaded(document)
    }

    /// Forward migration hook. Schema 1 is the first saved format, so there is nothing to
    /// transform yet; later versions add a step here and keep every existing field.
    static func migrate(_ data: Data, from version: Int) throws -> Data {
        switch version {
        case 1: return data
        default: throw CocoaError(.fileReadCorruptFile)
        }
    }

    static let documentKeys: Set<String> = ["schemaVersion", "preferences", "squares", "history"]
    static let preferenceKeys: Set<String> = ["squareSize", "opacity", "playSound", "feedbackMode", "positionsLocked",
                                              "launchAtLogin", "squaresHidden", "hideShowShortcut", "snapShortcut"]
    static let squareKeys: Set<String> = ["id", "label", "text", "placement", "shortcut"]
    static let placementKeys: Set<String> = ["displayID", "x", "y", "displayWidth", "displayHeight"]
    static let shortcutKeys: Set<String> = ["keyCode", "modifiers"]
    static let historyKeys: Set<String> = ["id", "text", "label", "lastUsed"]

    /// Name of the first field schema 1 does not define, if any.
    static func unknownKey(in document: [String: Any]) -> String? {
        func extra(_ object: Any?, _ allowed: Set<String>) -> String? {
            guard let dict = object as? [String: Any] else { return nil }
            return dict.keys.sorted().first { !allowed.contains($0) }
        }
        if let key = extra(document, documentKeys) { return key }
        let prefs = document["preferences"] as? [String: Any]
        if let key = extra(prefs, preferenceKeys) ?? extra(prefs?["hideShowShortcut"], shortcutKeys) ?? extra(prefs?["snapShortcut"], shortcutKeys) { return key }
        for square in document["squares"] as? [[String: Any]] ?? [] {
            if let key = extra(square, squareKeys) ?? extra(square["placement"], placementKeys) ?? extra(square["shortcut"], shortcutKeys) { return key }
        }
        for entry in document["history"] as? [[String: Any]] ?? [] {
            if let key = extra(entry, historyKeys) { return key }
        }
        return nil
    }

    static func validationProblem(_ document: ConfigDocument) -> String? {
        var ids = Set<UUID>()
        for square in document.squares {
            if LabelRules.validate(square.label) != nil { return "invalid label" }
            if !ids.insert(square.id).inserted { return "duplicate square id" }
        }
        return nil
    }
}

/// Reads and safely writes `config.json` in one directory. The directory is injectable so
/// tests and development runs never touch the live Application Support folder.
public struct ConfigFileStore: Sendable {
    public static let fileName = "config.json"
    public let directory: URL

    public init(directory: URL) {
        self.directory = directory
    }

    public var fileURL: URL { directory.appendingPathComponent(Self.fileName) }

    /// The live location (Decisions #32, #35).
    public static func defaultDirectory() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("com.dweebzxx.yoink", isDirectory: true)
    }

    public func ensureDirectory() throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
    }

    public func load() -> LoadResult {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return .notFound }
        guard let data = try? Data(contentsOf: fileURL) else { return .corrupt(.unreadable) }
        return ConfigCodec.decode(data)
    }

    /// Safe write: the complete document goes to a temporary file (mode 0600) in the same
    /// folder, is flushed, and only then atomically replaces the previous file. On any
    /// failure the previous valid document stays in place.
    public func save(_ document: ConfigDocument) throws {
        let data = try ConfigCodec.encode(document)
        try ensureDirectory()
        let temp = directory.appendingPathComponent(".\(Self.fileName).\(UUID().uuidString).tmp")
        guard FileManager.default.createFile(atPath: temp.path, contents: nil, attributes: [.posixPermissions: 0o600]) else {
            throw CocoaError(.fileWriteNoPermission)
        }
        do {
            let handle = try FileHandle(forWritingTo: temp)
            try handle.write(contentsOf: data)
            try handle.synchronize()
            try handle.close()
            if rename(temp.path, fileURL.path) != 0 { throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO) }
        } catch {
            try? FileManager.default.removeItem(at: temp)
            throw error
        }
    }

    /// Start Fresh (Decision #28): renames the unreadable file to a timestamped backup in the
    /// same folder. Returns the backup location.
    @discardableResult
    public func backUpUnreadableFile(now: Date = Date()) throws -> URL {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        var backup = directory.appendingPathComponent("config.unreadable-\(formatter.string(from: now)).json")
        var counter = 2
        while FileManager.default.fileExists(atPath: backup.path) {
            backup = directory.appendingPathComponent("config.unreadable-\(formatter.string(from: now))-\(counter).json")
            counter += 1
        }
        try FileManager.default.moveItem(at: fileURL, to: backup)
        return backup
    }
}

/// Only one process may own a configuration folder (architecture spec, Lifecycle).
public final class InstanceLock: @unchecked Sendable {
    private let descriptor: Int32

    /// Returns nil when another process already holds the lock for `directory`.
    public init?(directory: URL) {
        let path = directory.appendingPathComponent(".lock").path
        let fd = open(path, O_CREAT | O_RDWR, 0o600)
        guard fd >= 0 else { return nil }
        guard flock(fd, LOCK_EX | LOCK_NB) == 0 else {
            close(fd)
            return nil
        }
        descriptor = fd
    }

    deinit {
        flock(descriptor, LOCK_UN)
        close(descriptor)
    }
}
