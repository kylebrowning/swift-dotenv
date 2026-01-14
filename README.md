# DotEnv

A type-safe `.env` file parser for Swift.

## Features

- Type-safe access to environment variables with generics
- Built-in support for `String`, `Int`, `Double`, `Float`, `Bool`, and `URL`
- Custom type support via `DotEnvRepresentable` protocol
- Configuration structs via `DotEnvConfigurable` protocol
- Quoted values (single and double quotes) with escape sequence support
- Merge multiple `.env` files with override precedence
- Load values into process environment
- Swift 6 concurrency support (`Sendable`)
- `Codable` and `ExpressibleByDictionaryLiteral` conformance

## Installation

Add the package to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/kylebrowning/dotenv", from: "1.0.0")
]
```

Then add `dotenv` to your target dependencies:

```swift
.target(
    name: "YourTarget",
    dependencies: ["dotenv"]
)
```

## Usage

### Basic Usage

```swift
import dotenv

// Load from file
let env = try DotEnv(path: ".env")

// Type-safe access
let port: Int = try env.require("PORT")
let debug: Bool = env.get("DEBUG") ?? false
let timeout: Int = env.get("TIMEOUT", default: 30)

// Check if key exists
if env.has("API_KEY") {
    let key: String = try env.require("API_KEY")
}

// Raw string access
let value = env["SOME_KEY"]
```

### Configuration Structs

Create type-safe configuration by conforming to `DotEnvConfigurable`:

```swift
struct AppConfig: DotEnvConfigurable {
    let databaseURL: String
    let port: Int
    let debug: Bool
    let apiKey: String

    init(from env: DotEnv) throws {
        self.databaseURL = try env.require("DATABASE_URL")
        self.port = try env.require("PORT")
        self.debug = env.get("DEBUG") ?? false
        self.apiKey = try env.require("API_KEY")
    }
}

// Load from file
let config = try AppConfig.load(from: ".env")

// Load from multiple files (later files override earlier)
let config = try AppConfig.load(from: [".env", ".env.local"])

// Load from string
let config = try AppConfig.load(contents: "PORT=8080\nDEBUG=true")
```

### Custom Types

Conform your types to `DotEnvRepresentable` for type-safe parsing:

```swift
enum Environment: String, DotEnvRepresentable {
    case development
    case staging
    case production
}

let env = try DotEnv(path: ".env")
let appEnv: Environment? = env.get("APP_ENV")
```

Enums with `String` or `Int` raw values automatically get `DotEnvRepresentable` conformance.

### Merging Files

```swift
// Merge multiple files (later files take precedence)
let env = try DotEnv.merged(from: ".env", ".env.local", ".env.development")

// Or merge manually
let base = try DotEnv(path: ".env")
let local = try DotEnv(path: ".env.local")
let merged = base.merging(with: local)

// Load with common overrides pattern (.env + .env.local)
let env = try DotEnv.loadWithOverrides()

// Auto-detect from common locations
let env = try DotEnv.loadDefault() // Searches: .env.local, .env, .env.development
```

### Process Environment

Load values into the process environment:

```swift
let env = try DotEnv(path: ".env")

// Load without overwriting existing vars
env.loadIntoProcessEnvironment()

// Load and overwrite existing vars
env.loadIntoProcessEnvironment(overwrite: true)

// Values now accessible via ProcessInfo
let value = ProcessInfo.processInfo.environment["MY_KEY"]
```

### Other Initializers

```swift
// From string contents
let env = DotEnv(contents: "KEY=value\nPORT=8080")

// From dictionary
let env = DotEnv(values: ["KEY": "value", "PORT": "8080"])

// Dictionary literal
let env: DotEnv = ["KEY": "value", "PORT": "8080"]

// Empty
let env = DotEnv()
```

## .env File Format

```bash
# Comments start with #
API_KEY=your_api_key_here

# Quoted values preserve spaces
MESSAGE="Hello, World!"
SINGLE='No escape processing'

# Double quotes support escape sequences
MULTILINE="Line 1\nLine 2"
WITH_TAB="Col1\tCol2"

# Values can contain equals signs
CONNECTION=host=localhost;port=5432

# Whitespace around = is trimmed
KEY = value
```

## Boolean Parsing

The following values are recognized as booleans (case-insensitive):

| True | False |
|------|-------|
| `true` | `false` |
| `yes` | `no` |
| `1` | `0` |
| `on` | `off` |

## Error Handling

```swift
do {
    let env = try DotEnv(path: ".env")
    let port: Int = try env.require("PORT")
} catch let error as DotEnvError {
    switch error {
    case .fileNotFound(let path):
        print("File not found: \(path)")
    case .missingKey(let key):
        print("Missing required key: \(key)")
    case .invalidValue(let key, let value, let type):
        print("Cannot convert '\(value)' to \(type) for '\(key)'")
    case .readError(let path, let underlying):
        print("Failed to read '\(path)': \(underlying)")
    }
}
```

## License

MIT
