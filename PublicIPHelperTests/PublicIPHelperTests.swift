//
//  PublicIPHelperTests.swift
//  PublicIPHelperTests
//
//  Created by Dave Barnwell on 07/10/2024.
//

import Testing
@testable import PublicIPHelper

struct PublicIPHelperTests {

    @Test func example() async throws {
        // Write your test here and use APIs like `#expect(...)` to check expected conditions.
    }

    @Test func testFetchPublicIP() async throws {
        let helper = PublicIPHelper()
        let ip = try await helper.fetchPublicIP()
        #expect(ip).toNotBeNil()
        #expect(ip).toMatchRegex(#"^\d{1,3}(\.\d{1,3}){3}$"#) // Validate IPv4 format
    }

    @Test func testPublicIPCache() async throws {
        let helper = PublicIPHelper()
        let firstIP = try await helper.fetchPublicIP()
        let cachedIP = helper.cachedPublicIP
        #expect(firstIP).toNotBeNil()
        #expect(cachedIP).toEqual(firstIP)
    }

    @Test func testInvalidResponseHandling() async throws {
        let mockHelper = MockPublicIPHelper(response: "Invalid Response")
        do {
            _ = try await mockHelper.fetchPublicIP()
            #fail("Expected fetchPublicIP to throw")
        } catch {
            #expect(error).toBeOfType(APIError.self)
        }
    }

}
