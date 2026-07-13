//
//  BenchJWTSignerTests.swift
//  BenchAuthCoreTests
//

import CryptoKit
import Foundation
import XCTest

@testable import BenchAuthCore

// Public key matching the private key embedded in BenchJWTSigner — used to verify signatures.
private let testPublicKeyPEM = """
    -----BEGIN PUBLIC KEY-----
    MFkwEwYHKoZIzj0CAQYIKoZIzj0DAQcDQgAE7MDJQaNKubLNY9eD/OznIA1hgLgy
    c71HdmuX7LNQgEgqRDLnyNu9AygPGOV9S6YoLHf0PyfyyThVZjEbvKjzKA==
    -----END PUBLIC KEY-----
    """

final class BenchJWTSignerTests: XCTestCase {
    let signer = BenchJWTSigner()

    // MARK: - Structure

    func testTokenHasThreeParts() {
        let token = signer.makeJWT(userID: "test-user")
        let parts = token.split(separator: ".", omittingEmptySubsequences: false)
        XCTAssertEqual(parts.count, 3)
    }

    // MARK: - Header

    func testHeaderAlgorithmIsES256() throws {
        let token = signer.makeJWT(userID: "test-user")
        let parts = token.split(separator: ".", omittingEmptySubsequences: false)
        let header = try decodeBase64URLJSON(String(parts[0]))
        XCTAssertEqual(header["alg"] as? String, "ES256")
        XCTAssertEqual(header["typ"] as? String, "JWT")
    }

    // MARK: - Payload

    func testPayloadSubMatchesUserID() throws {
        let token = signer.makeJWT(userID: "alice@example.com")
        let parts = token.split(separator: ".", omittingEmptySubsequences: false)
        let payload = try decodeBase64URLJSON(String(parts[1]))
        XCTAssertEqual(payload["sub"] as? String, "alice@example.com")
    }

    func testPayloadExpIs600SecondsAfterIat() throws {
        let before = Int(Date().timeIntervalSince1970)
        let token = signer.makeJWT(userID: "test-user")
        let after = Int(Date().timeIntervalSince1970)
        let parts = token.split(separator: ".", omittingEmptySubsequences: false)
        let payload = try decodeBase64URLJSON(String(parts[1]))
        let iat = try XCTUnwrap(payload["iat"] as? Int)
        let exp = try XCTUnwrap(payload["exp"] as? Int)
        XCTAssertEqual(exp - iat, 600)
        XCTAssertGreaterThanOrEqual(iat, before)
        XCTAssertLessThanOrEqual(iat, after)
    }

    // MARK: - Signature

    func testSignatureIsValidES256() throws {
        let token = signer.makeJWT(userID: "test-user")
        let parts = token.split(separator: ".", omittingEmptySubsequences: false)
        let signingInput = "\(parts[0]).\(parts[1])"

        // Signature must be 64 bytes (raw r||s for P-256)
        let sigData = try base64URLDecode(String(parts[2]))
        XCTAssertEqual(sigData.count, 64, "ES256 signature must be 64 bytes (raw r||s, not DER)")

        // Verify against the embedded public key.
        // Note: CryptoKit's isValidSignature(_:for:) hashes the data with SHA-256 implicitly —
        // pass the raw signing input bytes, not a pre-hashed digest.
        let publicKey = try P256.Signing.PublicKey(pemRepresentation: testPublicKeyPEM)
        let ecdsaSig = try P256.Signing.ECDSASignature(rawRepresentation: sigData)
        XCTAssertTrue(publicKey.isValidSignature(ecdsaSig, for: Data(signingInput.utf8)))
    }

    // MARK: - Helpers

    private func decodeBase64URLJSON(_ encoded: String) throws -> [String: Any] {
        let data = try base64URLDecode(encoded)
        let json = try JSONSerialization.jsonObject(with: data)
        return try XCTUnwrap(json as? [String: Any])
    }

    private func base64URLDecode(_ encoded: String) throws -> Data {
        var base64 =
            encoded
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        let remainder = base64.count % 4
        if remainder != 0 { base64 += String(repeating: "=", count: 4 - remainder) }
        return try XCTUnwrap(Data(base64Encoded: base64))
    }
}
