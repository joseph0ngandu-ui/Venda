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
}
