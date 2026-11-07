import Foundation
import Testing
@testable import Pocketknife

struct TextTransformsTests {
    @Test func formatsJSONKeepingKeyOrder() throws {
        let output = try TextTransforms.formatJSON(#"{"b":1,"a":[1,2],"e":{},"s":"x, {y}: \"z\""}"#)
        #expect(output == """
        {
          "b": 1,
          "a": [
            1,
            2
          ],
          "e": {},
          "s": "x, {y}: \\"z\\""
        }
        """)
    }

    @Test func minifiesJSON() throws {
        #expect(try TextTransforms.minifyJSON("{\n  \"a\" : [ 1, 2 ],\n  \"b\": \"x y\"\n}") == #"{"a":[1,2],"b":"x y"}"#)
    }

    @Test func rejectsInvalidJSON() {
        #expect(throws: TransformError.self) { try TextTransforms.formatJSON("{\"a\":}") }
    }

    @Test func formatsAndMinifiesXML() throws {
        let xml = "<root><item id=\"1\">hi</item><empty></empty></root>"
        let pretty = try TextTransforms.formatXML(xml)
        #expect(pretty.contains("\n"))
        #expect(pretty.contains("<empty/>"))
        #expect(try TextTransforms.minifyXML(pretty) == "<root><item id=\"1\">hi</item><empty/></root>")
    }

    @Test func rejectsInvalidXML() {
        #expect(throws: TransformError.self) { try TextTransforms.formatXML("<root><a></root>") }
    }

    @Test func roundTripsBase64() throws {
        #expect(TextTransforms.encodeBase64("héllo?>") == "aMOpbGxvPz4=")
        #expect(TextTransforms.encodeBase64("héllo?>", urlSafe: true) == "aMOpbGxvPz4")
        #expect(try TextTransforms.decodeBase64("aMOpbGxvPz4=") == "héllo?>")
        #expect(try TextTransforms.decodeBase64(" aMOpbGx\nvPz4 ") == "héllo?>")
    }

    @Test func rejectsInvalidBase64() {
        #expect(throws: TransformError.self) { try TextTransforms.decodeBase64("not base64!") }
    }

    // {"alg":"HS256","typ":"JWT"} . {"sub":"123","exp":1700000000} . signature
    private static let sampleJWT = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjMiLCJleHAiOjE3MDAwMDAwMDB9.c2lnbmF0dXJl"

    @Test func decodesJWT() throws {
        let expired = try TextTransforms.decodeJWT(Self.sampleJWT, now: Date(timeIntervalSince1970: 1_800_000_000))
        #expect(expired.contains("\"alg\": \"HS256\""))
        #expect(expired.contains("\"sub\": \"123\""))
        #expect(expired.contains("2023-11-14T22:13:20Z  (expired)"))
        #expect(expired.contains("c2lnbmF0dXJl\n(not verified)"))

        let valid = try TextTransforms.decodeJWT("Bearer \(Self.sampleJWT)", now: Date(timeIntervalSince1970: 1_600_000_000))
        #expect(valid.contains("(valid)"))
    }

    @Test func rejectsInvalidJWT() {
        #expect(throws: TransformError.self) { try TextTransforms.decodeJWT("only.two") }
        #expect(throws: TransformError.self) { try TextTransforms.decodeJWT("bm90anNvbg.bm90anNvbg.sig") }
        #expect(throws: TransformError.self) { try TextTransforms.decodeJWT("!!!.!!!.sig") }
    }
}
