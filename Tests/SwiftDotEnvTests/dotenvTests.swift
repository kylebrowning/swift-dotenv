import Testing
import Foundation
@testable import SwiftDotEnv

// MARK: - Basic Parsing Tests

@Test func parseSimpleKeyValue() throws {
    let env = DotEnv(contents: "MYAPIKEY=1234567")

    #expect(env["MYAPIKEY"] == "1234567")
}

@Test func parseMultipleValues() throws {
    let contents = """
    MYAPIKEY=1234567
    DATABASE_URL=postgres://localhost/mydb
    PORT=8080
    """
    let env = DotEnv(contents: contents)

    #expect(env["MYAPIKEY"] == "1234567")
    #expect(env["DATABASE_URL"] == "postgres://localhost/mydb")
    #expect(env["PORT"] == "8080")
}

@Test func skipCommentsAndEmptyLines() throws {
    let contents = """
    # This is a comment
    MYAPIKEY=1234567

    # Another comment
    DEBUG=true
    """
    let env = DotEnv(contents: contents)

    #expect(env.values.count == 2)
    #expect(env["MYAPIKEY"] == "1234567")
    #expect(env["DEBUG"] == "true")
}

@Test func handleQuotedValues() throws {
    let contents = """
    SINGLE_QUOTED='hello world'
    DOUBLE_QUOTED="hello world"
    UNQUOTED=hello
    """
    let env = DotEnv(contents: contents)

    #expect(env["SINGLE_QUOTED"] == "hello world")
    #expect(env["DOUBLE_QUOTED"] == "hello world")
    #expect(env["UNQUOTED"] == "hello")
}

@Test func handleEscapeSequences() throws {
    let contents = """
    WITH_NEWLINE="line1\\nline2"
    WITH_TAB="col1\\tcol2"
    """
    let env = DotEnv(contents: contents)

    #expect(env["WITH_NEWLINE"] == "line1\nline2")
    #expect(env["WITH_TAB"] == "col1\tcol2")
}

@Test func handleEqualsInValue() throws {
    let contents = "CONNECTION_STRING=host=localhost;user=admin"
    let env = DotEnv(contents: contents)

    #expect(env["CONNECTION_STRING"] == "host=localhost;user=admin")
}

// MARK: - Type-Safe Access Tests

@Test func getTypedValues() throws {
    let contents = """
    PORT=8080
    RATE=3.14
    DEBUG=true
    NAME=MyApp
    """
    let env = DotEnv(contents: contents)

    let port: Int? = env.get("PORT")
    let rate: Double? = env.get("RATE")
    let debug: Bool? = env.get("DEBUG")
    let name: String? = env.get("NAME")

    #expect(port == 8080)
    #expect(rate == 3.14)
    #expect(debug == true)
    #expect(name == "MyApp")
}

@Test func getWithDefault() throws {
    let env = DotEnv(contents: "PORT=8080")

    let port: Int = env.get("PORT", default: 3000)
    let timeout: Int = env.get("TIMEOUT", default: 30)

    #expect(port == 8080)
    #expect(timeout == 30)
}

@Test func requireExistingValue() throws {
    let env = DotEnv(contents: "PORT=8080")

    let port: Int = try env.require("PORT")
    #expect(port == 8080)
}

@Test func requireMissingValueThrows() throws {
    let env = DotEnv(contents: "PORT=8080")

    #expect(throws: DotEnvError.self) {
        let _: Int = try env.require("MISSING_KEY")
    }
}

@Test func requireInvalidTypeThrows() throws {
    let env = DotEnv(contents: "PORT=not_a_number")

    #expect(throws: DotEnvError.self) {
        let _: Int = try env.require("PORT")
    }
}

@Test func boolParsesVariousFormats() throws {
    let contents = """
    B1=true
    B2=false
    B3=yes
    B4=no
    B5=1
    B6=0
    B7=on
    B8=off
    B9=TRUE
    B10=FALSE
    """
    let env = DotEnv(contents: contents)

    #expect(env.get("B1") == true)
    #expect(env.get("B2") == false)
    #expect(env.get("B3") == true)
    #expect(env.get("B4") == false)
    #expect(env.get("B5") == true)
    #expect(env.get("B6") == false)
    #expect(env.get("B7") == true)
    #expect(env.get("B8") == false)
    #expect(env.get("B9") == true)
    #expect(env.get("B10") == false)
}

@Test func urlParsing() throws {
    let env = DotEnv(contents: "API_URL=https://api.example.com/v1")

    let url: URL? = env.get("API_URL")
    #expect(url?.absoluteString == "https://api.example.com/v1")
}

// MARK: - DotEnvConfigurable Tests

struct AppConfig: DotEnvConfigurable {
    let apiKey: String
    let port: Int
    let debug: Bool
    let timeout: Int

    init(from env: DotEnv) throws {
        self.apiKey = try env.require("MYAPIKEY")
        self.port = try env.require("PORT")
        self.debug = env.get("DEBUG") ?? false
        self.timeout = env.get("TIMEOUT", default: 30)
    }
}

@Test func loadConfigurableFromContents() throws {
    let contents = """
    MYAPIKEY=1234567
    PORT=8080
    DEBUG=true
    """

    let config = try AppConfig.load(contents: contents)

    #expect(config.apiKey == "1234567")
    #expect(config.port == 8080)
    #expect(config.debug == true)
    #expect(config.timeout == 30) // default value
}

@Test func configurableWithMissingRequiredKeyThrows() throws {
    let contents = """
    PORT=8080
    """

    #expect(throws: DotEnvError.self) {
        _ = try AppConfig.load(contents: contents)
    }
}

// MARK: - Custom Type Tests

enum Environment: String, DotEnvRepresentable {
    case development
    case staging
    case production
}

@Test func customEnumType() throws {
    let env = DotEnv(contents: "APP_ENV=production")

    let appEnv: Environment? = env.get("APP_ENV")
    #expect(appEnv == .production)
}

@Test func customEnumTypeInvalid() throws {
    let env = DotEnv(contents: "APP_ENV=invalid")

    let appEnv: Environment? = env.get("APP_ENV")
    #expect(appEnv == nil)
}

// MARK: - Utility Tests

@Test func hasKey() throws {
    let env = DotEnv(contents: "MYAPIKEY=1234567")

    #expect(env.has("MYAPIKEY") == true)
    #expect(env.has("MISSING") == false)
}

@Test func keysProperty() throws {
    let contents = """
    KEY1=value1
    KEY2=value2
    """
    let env = DotEnv(contents: contents)

    #expect(env.keys.count == 2)
    #expect(env.keys.contains("KEY1"))
    #expect(env.keys.contains("KEY2"))
}

@Test func merging() throws {
    let base = DotEnv(contents: """
    KEY1=base1
    KEY2=base2
    """)

    let override = DotEnv(contents: """
    KEY2=override2
    KEY3=override3
    """)

    let merged = base.merging(with: override)

    #expect(merged["KEY1"] == "base1")
    #expect(merged["KEY2"] == "override2")  // overridden
    #expect(merged["KEY3"] == "override3")
}

@Test func dictionaryLiteralInit() throws {
    let env: DotEnv = [
        "MYAPIKEY": "1234567",
        "PORT": "8080"
    ]

    #expect(env["MYAPIKEY"] == "1234567")
    #expect(env["PORT"] == "8080")
}

@Test func emptyInit() throws {
    let env = DotEnv()

    #expect(env.values.isEmpty)
    #expect(env.sourcePath == nil)
}

@Test func valuesInit() throws {
    let env = DotEnv(values: ["MYAPIKEY": "1234567"])

    #expect(env["MYAPIKEY"] == "1234567")
}

// MARK: - Edge Cases

@Test func whitespaceHandling() throws {
    let contents = """
      KEY1  =  value1
    KEY2=  value2
    KEY3  =value3
    """
    let env = DotEnv(contents: contents)

    #expect(env["KEY1"] == "value1")
    #expect(env["KEY2"] == "value2")
    #expect(env["KEY3"] == "value3")
}

@Test func emptyValue() throws {
    let env = DotEnv(contents: "EMPTY=")

    #expect(env["EMPTY"] == "")
}

@Test func lineWithoutEquals() throws {
    let contents = """
    VALID=value
    INVALID_LINE
    ALSO_VALID=another
    """
    let env = DotEnv(contents: contents)

    #expect(env.values.count == 2)
    #expect(env["VALID"] == "value")
    #expect(env["ALSO_VALID"] == "another")
}
