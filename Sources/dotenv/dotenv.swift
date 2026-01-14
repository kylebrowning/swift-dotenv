// DotEnv - A type-safe .env file parser for Swift
// https://github.com/kylebrowning/dotenv

import Foundation

// MARK: - Errors

/// Errors that can occur when parsing or accessing .env values
public enum DotEnvError: Error, CustomStringConvertible {
    /// The specified file could not be found
    case fileNotFound(String)

    /// A required key is missing from the environment
    case missingKey(String)

    /// A value could not be converted to the expected type
    case invalidValue(key: String, value: String, expectedType: Any.Type)

    /// Failed to read the file contents
    case readError(String, underlying: Error)

    public var description: String {
        switch self {
        case .fileNotFound(let path):
            return "Environment file not found: \(path)"
        case .missingKey(let key):
            return "Missing required environment variable: \(key)"
        case .invalidValue(let key, let value, let type):
            return "Cannot convert '\(value)' to \(type) for key '\(key)'"
        case .readError(let path, let error):
            return "Failed to read '\(path)': \(error.localizedDescription)"
        }
    }
}

// MARK: - Value Conversion Protocol

/// A type that can be initialized from an environment variable string value.
///
/// Conform your custom types to this protocol to enable type-safe extraction
/// from environment variables.
///
/// Example:
/// ```swift
/// enum Environment: String, DotEnvRepresentable {
///     case development, staging, production
/// }
/// ```
public protocol DotEnvRepresentable {
    /// Attempts to create an instance from a string value
    /// - Parameter value: The string value from the environment
    /// - Returns: An instance of Self, or nil if conversion fails
    static func fromEnvValue(_ value: String) -> Self?
}

// MARK: - Default Conformances

extension String: DotEnvRepresentable {
    public static func fromEnvValue(_ value: String) -> String? {
        return value
    }
}

extension Int: DotEnvRepresentable {
    public static func fromEnvValue(_ value: String) -> Int? {
        return Int(value)
    }
}

extension Double: DotEnvRepresentable {
    public static func fromEnvValue(_ value: String) -> Double? {
        return Double(value)
    }
}

extension Float: DotEnvRepresentable {
    public static func fromEnvValue(_ value: String) -> Float? {
        return Float(value)
    }
}

extension Bool: DotEnvRepresentable {
    public static func fromEnvValue(_ value: String) -> Bool? {
        let lowercased = value.lowercased()
        switch lowercased {
        case "true", "yes", "1", "on":
            return true
        case "false", "no", "0", "off":
            return false
        default:
            return nil
        }
    }
}

extension URL: DotEnvRepresentable {
    public static func fromEnvValue(_ value: String) -> URL? {
        return URL(string: value)
    }
}

extension Optional: DotEnvRepresentable where Wrapped: DotEnvRepresentable {
    public static func fromEnvValue(_ value: String) -> Optional<Wrapped>? {
        return Wrapped.fromEnvValue(value)
    }
}

// Support for RawRepresentable types (enums with raw values)
extension DotEnvRepresentable where Self: RawRepresentable, RawValue == String {
    public static func fromEnvValue(_ value: String) -> Self? {
        return Self(rawValue: value)
    }
}

extension DotEnvRepresentable where Self: RawRepresentable, RawValue == Int {
    public static func fromEnvValue(_ value: String) -> Self? {
        guard let intValue = Int(value) else { return nil }
        return Self(rawValue: intValue)
    }
}

// MARK: - DotEnv Parser

/// A parser and container for environment variables loaded from a .env file.
///
/// Use `DotEnv` to load environment variables from a file and access them
/// in a type-safe manner.
///
/// ## Basic Usage
/// ```swift
/// let env = try DotEnv(path: ".env")
/// let port: Int = try env.require("PORT")
/// let debug: Bool = env.get("DEBUG") ?? false
/// ```
///
/// ## With Custom Configuration Struct
/// ```swift
/// struct AppConfig: DotEnvConfigurable {
///     let databaseURL: String
///     let port: Int
///     let debug: Bool
///
///     init(from env: DotEnv) throws {
///         self.databaseURL = try env.require("DATABASE_URL")
///         self.port = try env.require("PORT")
///         self.debug = env.get("DEBUG") ?? false
///     }
/// }
///
/// let config = try AppConfig.load(from: ".env")
/// ```
public struct DotEnv: Sendable {
    /// The raw key-value pairs parsed from the environment file
    public let values: [String: String]

    /// The path the environment was loaded from (if loaded from file)
    public let sourcePath: String?

    // MARK: - Initialization

    /// Creates a DotEnv instance by parsing the contents of a file at the given path.
    ///
    /// - Parameter path: The path to the .env file (relative or absolute)
    /// - Throws: `DotEnvError.fileNotFound` if the file doesn't exist,
    ///           `DotEnvError.readError` if the file can't be read
    public init(path: String) throws {
        let fileManager = FileManager.default
        let absolutePath: String

        if path.hasPrefix("/") {
            absolutePath = path
        } else {
            absolutePath = fileManager.currentDirectoryPath + "/" + path
        }

        guard fileManager.fileExists(atPath: absolutePath) else {
            throw DotEnvError.fileNotFound(absolutePath)
        }

        let contents: String
        do {
            contents = try String(contentsOfFile: absolutePath, encoding: .utf8)
        } catch {
            throw DotEnvError.readError(absolutePath, underlying: error)
        }

        self.values = Self.parse(contents)
        self.sourcePath = absolutePath
    }

    /// Creates a DotEnv instance by parsing the given string contents.
    ///
    /// - Parameter contents: The .env file contents as a string
    public init(contents: String) {
        self.values = Self.parse(contents)
        self.sourcePath = nil
    }

    /// Creates an empty DotEnv instance.
    public init() {
        self.values = [:]
        self.sourcePath = nil
    }

    /// Creates a DotEnv instance from an existing dictionary.
    ///
    /// - Parameter values: A dictionary of key-value pairs
    public init(values: [String: String]) {
        self.values = values
        self.sourcePath = nil
    }

    // MARK: - Parsing

    private static func parse(_ contents: String) -> [String: String] {
        var result: [String: String] = [:]
        let lines = contents.components(separatedBy: .newlines)

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // Skip empty lines and comments
            if trimmed.isEmpty || trimmed.hasPrefix("#") {
                continue
            }

            // Find the first equals sign
            guard let equalsIndex = trimmed.firstIndex(of: "=") else {
                continue
            }

            let key = String(trimmed[..<equalsIndex]).trimmingCharacters(in: .whitespaces)
            var value = String(trimmed[trimmed.index(after: equalsIndex)...]).trimmingCharacters(in: .whitespaces)

            // Skip if key is empty
            if key.isEmpty {
                continue
            }

            // Handle quoted values
            value = unquote(value)

            result[key] = value
        }

        return result
    }

    private static func unquote(_ value: String) -> String {
        var result = value

        // Handle double quotes
        if result.hasPrefix("\"") && result.hasSuffix("\"") && result.count >= 2 {
            result = String(result.dropFirst().dropLast())
            // Process escape sequences in double-quoted strings
            result = result
                .replacingOccurrences(of: "\\n", with: "\n")
                .replacingOccurrences(of: "\\r", with: "\r")
                .replacingOccurrences(of: "\\t", with: "\t")
                .replacingOccurrences(of: "\\\"", with: "\"")
                .replacingOccurrences(of: "\\\\", with: "\\")
        }
        // Handle single quotes (no escape processing)
        else if result.hasPrefix("'") && result.hasSuffix("'") && result.count >= 2 {
            result = String(result.dropFirst().dropLast())
        }

        return result
    }

    // MARK: - Type-Safe Value Access

    /// Returns the raw string value for a key, or nil if not present.
    ///
    /// - Parameter key: The environment variable name
    /// - Returns: The string value, or nil if not found
    public subscript(key: String) -> String? {
        return values[key]
    }

    /// Returns a typed value for the given key, or nil if not present or conversion fails.
    ///
    /// - Parameter key: The environment variable name
    /// - Returns: The converted value, or nil if not found or conversion fails
    public func get<T: DotEnvRepresentable>(_ key: String) -> T? {
        guard let stringValue = values[key] else {
            return nil
        }
        return T.fromEnvValue(stringValue)
    }

    /// Returns a typed value for the given key, or the default if not present or conversion fails.
    ///
    /// - Parameters:
    ///   - key: The environment variable name
    ///   - default: The default value to return if the key is missing or conversion fails
    /// - Returns: The converted value, or the default value
    public func get<T: DotEnvRepresentable>(_ key: String, default defaultValue: T) -> T {
        return get(key) ?? defaultValue
    }

    /// Returns a typed value for the given key, throwing if not present or conversion fails.
    ///
    /// - Parameter key: The environment variable name
    /// - Returns: The converted value
    /// - Throws: `DotEnvError.missingKey` if the key is not found,
    ///           `DotEnvError.invalidValue` if conversion fails
    public func require<T: DotEnvRepresentable>(_ key: String) throws -> T {
        guard let stringValue = values[key] else {
            throw DotEnvError.missingKey(key)
        }
        guard let converted = T.fromEnvValue(stringValue) else {
            throw DotEnvError.invalidValue(key: key, value: stringValue, expectedType: T.self)
        }
        return converted
    }

    /// Checks if a key exists in the environment.
    ///
    /// - Parameter key: The environment variable name
    /// - Returns: true if the key exists, false otherwise
    public func has(_ key: String) -> Bool {
        return values[key] != nil
    }

    /// Returns all keys in the environment.
    public var keys: Dictionary<String, String>.Keys {
        return values.keys
    }

    // MARK: - Process Environment

    /// Loads the values into the current process environment.
    ///
    /// This makes the values available via `ProcessInfo.processInfo.environment`
    /// and the standard `getenv()` function.
    ///
    /// - Parameter overwrite: If true, overwrites existing environment variables.
    ///                        Defaults to false.
    public func loadIntoProcessEnvironment(overwrite: Bool = false) {
        for (key, value) in values {
            if overwrite || ProcessInfo.processInfo.environment[key] == nil {
                setenv(key, value, overwrite ? 1 : 0)
            }
        }
    }

    // MARK: - Merging

    /// Creates a new DotEnv by merging with another, with the other taking precedence.
    ///
    /// - Parameter other: The DotEnv to merge with
    /// - Returns: A new DotEnv with merged values
    public func merging(with other: DotEnv) -> DotEnv {
        return DotEnv(values: values.merging(other.values) { _, new in new })
    }

    /// Creates a new DotEnv by merging multiple .env files, later files take precedence.
    ///
    /// - Parameter paths: The paths to the .env files
    /// - Returns: A merged DotEnv instance
    /// - Throws: If any file cannot be read
    public static func merged(from paths: String...) throws -> DotEnv {
        return try merged(from: paths)
    }

    /// Creates a new DotEnv by merging multiple .env files, later files take precedence.
    ///
    /// - Parameter paths: An array of paths to the .env files
    /// - Returns: A merged DotEnv instance
    /// - Throws: If any file cannot be read
    public static func merged(from paths: [String]) throws -> DotEnv {
        var result = DotEnv()
        for path in paths {
            let env = try DotEnv(path: path)
            result = result.merging(with: env)
        }
        return result
    }
}

// MARK: - User Configuration Protocol

/// A protocol for creating type-safe configuration structs from environment variables.
///
/// Conform your configuration structs to this protocol to enable loading
/// from .env files with full type safety.
///
/// ## Example
/// ```swift
/// struct DatabaseConfig: DotEnvConfigurable {
///     let host: String
///     let port: Int
///     let username: String
///     let password: String
///     let database: String
///     let ssl: Bool
///
///     init(from env: DotEnv) throws {
///         self.host = try env.require("DB_HOST")
///         self.port = try env.require("DB_PORT")
///         self.username = try env.require("DB_USER")
///         self.password = try env.require("DB_PASSWORD")
///         self.database = try env.require("DB_NAME")
///         self.ssl = env.get("DB_SSL") ?? true
///     }
/// }
///
/// // Load from file
/// let dbConfig = try DatabaseConfig.load(from: ".env")
///
/// // Or load from multiple files (later files override earlier)
/// let dbConfig = try DatabaseConfig.load(from: [".env", ".env.local"])
/// ```
public protocol DotEnvConfigurable {
    /// Creates a configuration instance from the given environment.
    ///
    /// - Parameter env: The DotEnv instance containing the environment values
    /// - Throws: Any errors that occur during initialization (typically `DotEnvError`)
    init(from env: DotEnv) throws
}

extension DotEnvConfigurable {
    /// Loads the configuration from a .env file at the given path.
    ///
    /// - Parameter path: The path to the .env file
    /// - Returns: A configured instance of Self
    /// - Throws: `DotEnvError` if the file cannot be read or required values are missing
    public static func load(from path: String) throws -> Self {
        let env = try DotEnv(path: path)
        return try Self(from: env)
    }

    /// Loads the configuration from multiple .env files, with later files overriding earlier ones.
    ///
    /// - Parameter paths: An array of paths to .env files
    /// - Returns: A configured instance of Self
    /// - Throws: `DotEnvError` if any file cannot be read or required values are missing
    public static func load(from paths: [String]) throws -> Self {
        let env = try DotEnv.merged(from: paths)
        return try Self(from: env)
    }

    /// Loads the configuration from a DotEnv instance.
    ///
    /// - Parameter env: A pre-loaded DotEnv instance
    /// - Returns: A configured instance of Self
    /// - Throws: Any errors from the initializer
    public static func load(from env: DotEnv) throws -> Self {
        return try Self(from: env)
    }

    /// Loads the configuration from a string containing .env formatted content.
    ///
    /// - Parameter contents: The .env file contents as a string
    /// - Returns: A configured instance of Self
    /// - Throws: Any errors from the initializer
    public static func load(contents: String) throws -> Self {
        let env = DotEnv(contents: contents)
        return try Self(from: env)
    }
}

// MARK: - Convenience Extensions

extension DotEnv {
    /// Attempts to load from common .env file locations, returning the first successful load.
    ///
    /// Searches in order: `.env.local`, `.env`, `.env.development`
    ///
    /// - Returns: A DotEnv instance from the first file found
    /// - Throws: `DotEnvError.fileNotFound` if no files are found
    public static func loadDefault() throws -> DotEnv {
        let candidates = [".env.local", ".env", ".env.development"]

        for candidate in candidates {
            if FileManager.default.fileExists(atPath: candidate) {
                return try DotEnv(path: candidate)
            }
        }

        throw DotEnvError.fileNotFound("No .env file found in: \(candidates.joined(separator: ", "))")
    }

    /// Attempts to load and merge multiple common .env file locations.
    ///
    /// Loads in order (later overrides earlier): `.env`, `.env.local`
    ///
    /// - Returns: A merged DotEnv instance
    /// - Throws: If the base `.env` file cannot be read
    public static func loadWithOverrides() throws -> DotEnv {
        var env = try DotEnv(path: ".env")

        // Try to load .env.local as override (ignore if not present)
        if FileManager.default.fileExists(atPath: ".env.local") {
            let local = try DotEnv(path: ".env.local")
            env = env.merging(with: local)
        }

        return env
    }
}

// MARK: - Codable Support

extension DotEnv: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        self.values = try container.decode([String: String].self)
        self.sourcePath = nil
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(values)
    }
}

// MARK: - ExpressibleByDictionaryLiteral

extension DotEnv: ExpressibleByDictionaryLiteral {
    public init(dictionaryLiteral elements: (String, String)...) {
        var dict: [String: String] = [:]
        for (key, value) in elements {
            dict[key] = value
        }
        self.values = dict
        self.sourcePath = nil
    }
}

// MARK: - CustomStringConvertible

extension DotEnv: CustomStringConvertible {
    public var description: String {
        let source = sourcePath.map { " (from: \($0))" } ?? ""
        return "DotEnv\(source): \(values.count) values"
    }
}

// MARK: - CustomDebugStringConvertible

extension DotEnv: CustomDebugStringConvertible {
    public var debugDescription: String {
        var lines = ["DotEnv {"]
        if let path = sourcePath {
            lines.append("  source: \(path)")
        }
        lines.append("  values: [")
        for (key, value) in values.sorted(by: { $0.key < $1.key }) {
            // Mask potentially sensitive values
            let maskedValue = key.lowercased().contains(any: ["password", "secret", "key", "token"])
                ? "***"
                : value
            lines.append("    \(key): \(maskedValue)")
        }
        lines.append("  ]")
        lines.append("}")
        return lines.joined(separator: "\n")
    }
}

// MARK: - Private Helpers

private extension String {
    func contains(any substrings: [String]) -> Bool {
        for substring in substrings {
            if self.contains(substring) {
                return true
            }
        }
        return false
    }
}
