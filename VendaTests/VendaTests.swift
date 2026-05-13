//
//  VendaTests.swift
//  VendaTests
//
//  Created by Sal🥤 on 3/24/26.
//

import Testing
import SwiftUI
@testable import Venda

struct VendaTests {
    
    // MARK: - Design System Validation Tests
    
    @Test("DesignSystem spacing values are properly defined")
    func testSpacingValues() {
        #expect(DesignSystem.Spacing.xs == 4)
        #expect(DesignSystem.Spacing.sm == 8)
        #expect(DesignSystem.Spacing.md == 12)
        #expect(DesignSystem.Spacing.lg == 16)
        #expect(DesignSystem.Spacing.xl == 24)
        #expect(DesignSystem.Spacing.xxl == 32)
        #expect(DesignSystem.Spacing.xxxl == 40)
    }
    
    @Test("DesignSystem corner radius values are properly defined")
    func testCornerRadiusValues() {
        #expect(DesignSystem.Radius.sm == 8)
        #expect(DesignSystem.Radius.md == 12)
        #expect(DesignSystem.Radius.lg == 16)
        #expect(DesignSystem.Radius.xl == 22)
        #expect(DesignSystem.Radius.full == 999)
    }
    
    @Test("DesignSystem component sizes are properly defined")
    func testComponentSizeValues() {
        #expect(DesignSystem.ComponentSize.buttonHeightLarge == 52)
        #expect(DesignSystem.ComponentSize.buttonHeightSmall == 40)
        #expect(DesignSystem.ComponentSize.buttonHeightMini == 32)
        #expect(DesignSystem.ComponentSize.avatarSmall == 40)
        #expect(DesignSystem.ComponentSize.avatarMedium == 52)
        #expect(DesignSystem.ComponentSize.avatarLarge == 64)
        #expect(DesignSystem.ComponentSize.minTouchTarget == 44)
        #expect(DesignSystem.ComponentSize.progressDotSize == 8)
        #expect(DesignSystem.ComponentSize.businessTypeCardHeight == 88)
    }
    
    @Test("DesignSystem typography sizes are consistent")
    func testTypographyConsistency() {
        // Typography should be Font objects - just verify they can be used
        let h1Font = DesignSystem.Typography.h1
        let bodyFont = DesignSystem.Typography.body
        let labelFont = DesignSystem.Typography.label
        
        // Verify typography values are not nil
        #expect(h1Font != nil)
        #expect(bodyFont != nil)
        #expect(labelFont != nil)
    }
    
    @Test("DesignSystem opacity values are valid")
    func testOpacityValues() {
        #expect(DesignSystem.Opacity.disabled == 0.5)
        #expect(DesignSystem.Opacity.hover == 0.8)
        #expect(DesignSystem.Opacity.subtle == 0.6)
        #expect(DesignSystem.Opacity.muted == 0.7)
        #expect(DesignSystem.Opacity.minimal == 0.2)
    }
    
    @Test("DesignSystem animation durations are consistent")
    func testAnimationDurations() {
        #expect(DesignSystem.Animation.fast == 0.15)
        #expect(DesignSystem.Animation.normal == 0.3)
        #expect(DesignSystem.Animation.slow == 0.5)
    }
    
    // MARK: - Component Integration Tests
    
    @Test("VendaButton can be instantiated")
    func testVendaButtonInstantiation() {
        // Test that button can be instantiated
        let button = VendaButton(title: "Test", action: {})
        #expect(button is VendaButton)
    }
    
    @Test("Design system spacing scale is 4pt based")
    func testSpacingScaleBaseUnit() {
        let baseUnit: CGFloat = 4
        #expect(DesignSystem.Spacing.xs == baseUnit * 1)
        #expect(DesignSystem.Spacing.sm == baseUnit * 2)
        #expect(DesignSystem.Spacing.md == baseUnit * 3)
        #expect(DesignSystem.Spacing.lg == baseUnit * 4)
        #expect(DesignSystem.Spacing.xl == baseUnit * 6)
        #expect(DesignSystem.Spacing.xxl == baseUnit * 8)
        #expect(DesignSystem.Spacing.xxxl == baseUnit * 10)
    }

    @Test("API base URL resolution prefers environment overrides first")
    func testAPIBaseURLPrefersEnvironmentOverride() {
        let resolved = NetworkService.resolveAPIBaseURL(
            environment: ["VENDA_API_BASE_URL": "https://env.example.com/api/v1"],
            infoDictionary: [
                "VENDA_API_BASE_URL": "https://info.example.com/api/v1",
                "API_BASE_URL": "https://legacy.example.com/api/v1"
            ],
            userDefaultsValue: "https://defaults.example.com/api/v1"
        )

        #expect(resolved.absoluteString == "https://env.example.com/api/v1")
    }

    @Test("API base URL resolution falls back through Info.plist and UserDefaults candidates")
    func testAPIBaseURLFallbackOrder() {
        let infoResolved = NetworkService.resolveAPIBaseURL(
            environment: [:],
            infoDictionary: [
                "VENDA_API_BASE_URL": "https://info.example.com/api/v1",
                "API_BASE_URL": "https://legacy.example.com/api/v1"
            ],
            userDefaultsValue: "https://defaults.example.com/api/v1"
        )
        #expect(infoResolved.absoluteString == "https://info.example.com/api/v1")

        let legacyInfoResolved = NetworkService.resolveAPIBaseURL(
            environment: [:],
            infoDictionary: [
                "VENDA_API_BASE_URL": "   ",
                "API_BASE_URL": "https://legacy.example.com/api/v1"
            ],
            userDefaultsValue: "https://defaults.example.com/api/v1"
        )
        #expect(legacyInfoResolved.absoluteString == "https://legacy.example.com/api/v1")

        let userDefaultsResolved = NetworkService.resolveAPIBaseURL(
            environment: [:],
            infoDictionary: [:],
            userDefaultsValue: "https://defaults.example.com/api/v1"
        )
        #expect(userDefaultsResolved.absoluteString == "https://defaults.example.com/api/v1")
    }

    @Test("API base URL resolution ignores invalid candidates before using the fallback")
    func testAPIBaseURLIgnoresInvalidCandidates() {
        let resolved = NetworkService.resolveAPIBaseURL(
            environment: ["VENDA_API_BASE_URL": "not-a-url"],
            infoDictionary: [
                "VENDA_API_BASE_URL": "also-invalid",
                "API_BASE_URL": "https://legacy.example.com/api/v1"
            ],
            userDefaultsValue: "  ",
            fallbackURLString: "https://fallback.example.com/api/v1"
        )

        #expect(resolved.absoluteString == "https://legacy.example.com/api/v1")

        let fallbackResolved = NetworkService.resolveAPIBaseURL(
            environment: [:],
            infoDictionary: [:],
            userDefaultsValue: nil,
            fallbackURLString: "https://fallback.example.com/api/v1"
        )

        #expect(fallbackResolved.absoluteString == "https://fallback.example.com/api/v1")
    }

    @Test("API base URL resolution normalizes empty paths and trailing slashes")
    func testAPIBaseURLNormalization() {
        let appendedPath = NetworkService.resolveAPIBaseURL(
            environment: ["VENDA_API_BASE_URL": "https://env.example.com"],
            infoDictionary: [:],
            userDefaultsValue: nil
        )
        #expect(appendedPath.absoluteString == "https://env.example.com/api/v1")

        let trimmedSlash = NetworkService.resolveAPIBaseURL(
            environment: ["VENDA_API_BASE_URL": "https://env.example.com/api/v1/"],
            infoDictionary: [:],
            userDefaultsValue: nil
        )
        #expect(trimmedSlash.absoluteString == "https://env.example.com/api/v1")
    }

    @Test("API base URL resolution only accepts HTTP for local development hosts")
    func testAPIBaseURLRejectsUnsafeHTTPOverrides() {
        let localHTTP = NetworkService.resolveAPIBaseURL(
            environment: ["VENDA_API_BASE_URL": "http://localhost:3000"],
            infoDictionary: [:],
            userDefaultsValue: nil
        )
        #expect(localHTTP.absoluteString == "http://localhost:3000/api/v1")

        let privateLANHTTP = NetworkService.resolveAPIBaseURL(
            environment: ["VENDA_API_BASE_URL": "http://192.168.1.25:3000"],
            infoDictionary: [:],
            userDefaultsValue: nil
        )
        #expect(privateLANHTTP.absoluteString == "http://192.168.1.25:3000/api/v1")

        let rejectedRemoteHTTP = NetworkService.resolveAPIBaseURL(
            environment: ["VENDA_API_BASE_URL": "http://api.example.com/api/v1"],
            infoDictionary: ["VENDA_API_BASE_URL": "https://info.example.com/api/v1"],
            userDefaultsValue: nil
        )
        #expect(rejectedRemoteHTTP.absoluteString == "https://info.example.com/api/v1")
    }

    @Test("API base URL resolution rejects unexpected paths and URL fragments")
    func testAPIBaseURLRejectsUnexpectedShapes() {
        let rejectedPath = NetworkService.resolveAPIBaseURL(
            environment: ["VENDA_API_BASE_URL": "https://env.example.com/custom/api"],
            infoDictionary: ["VENDA_API_BASE_URL": "https://info.example.com/api/v1"],
            userDefaultsValue: nil
        )
        #expect(rejectedPath.absoluteString == "https://info.example.com/api/v1")

        let rejectedFragment = NetworkService.resolveAPIBaseURL(
            environment: ["VENDA_API_BASE_URL": "https://env.example.com/api/v1#fragment"],
            infoDictionary: ["VENDA_API_BASE_URL": "https://info.example.com/api/v1"],
            userDefaultsValue: nil
        )
        #expect(rejectedFragment.absoluteString == "https://info.example.com/api/v1")
    }
}
