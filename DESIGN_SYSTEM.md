## Venda Design System Documentation

This document outlines the standardized design system used throughout the Venda iOS application.

### Overview

The Venda design system ensures consistency, maintainability, and professional polish across the entire app. All components should use the centralized `DesignSystem` constants rather than hardcoded values.

---

## Spacing Scale

All spacing should use multiples of 4dp. The standardized scale is:

- **xs**: 4pt - minimal spacing between elements
- **sm**: 8pt - small spacing
- **md**: 12pt - default spacing between components
- **lg**: 16pt - standard horizontal padding / spacing
- **xl**: 24pt - spacing between sections
- **xxl**: 32pt - larger section spacing
- **xxxl**: 40pt - screen-level padding

**Usage:**
```swift
.padding(DesignSystem.Spacing.lg)
VStack(spacing: DesignSystem.Spacing.md) { ... }
```

---

## Typography Scale

Use the pre-defined typography constants. Never use `Font.system()` with hardcoded values.

### Headings
- **h1**: 28pt, Bold - Main page title
- **h2**: 24pt, Semibold - Section header
- **h3**: 20pt, Semibold - Subsection header
- **h4**: 18pt, Semibold - Card title

### Body Text
- **body**: 16pt, Regular - Default body text
- **bodySemibold**: 16pt, Semibold - Emphasized body
- **bodyMedium**: 15pt, Medium - Data/values
- **bodySmall**: 14pt, Regular - Secondary text

### Labels & Captions
- **label**: 12pt, Semibold - Form labels
- **caption**: 11pt, Medium - Secondary labels
- **captionSmall**: 10pt, Regular - Minimal text

### Interactive
- **button**: 15pt, Semibold - Button text
- **buttonSmall**: 13pt, Semibold - Compact buttons

**Usage:**
```swift
Text("Heading")
    .font(DesignSystem.Typography.h2)
```

---

## Corner Radius

- **sm**: 8pt - Small buttons, badges
- **md**: 12pt - Cards, input fields, standard containers
- **lg**: 16pt - Modals, larger containers
- **xl**: 22pt - Tab bar, large surfaces
- **full**: 999pt - Completely rounded (pills, circles)

**Usage:**
```swift
.cornerRadius(DesignSystem.Radius.md)
```

---

## Component Sizes

### Buttons
- **Large**: 52pt height (default)
- **Medium**: 44pt height (supplementary)
- **Small**: 40pt height (inline)

### Icons
- **Large**: 24pt
- **Medium**: 18pt
- **Small**: 16pt

### Avatars
- **Large**: 64pt
- **Medium**: 52pt  
- **Small**: 40pt

**Minimum touch target**: 44pt (accessibility requirement)

---

## Color Usage

### Venda Colors
Primary colors and their variants are defined in `Color+Venda.swift`:

- **vendaForest** - Primary action color
- **vendaOchre** - Secondary/warning color
- **vendaEmber** - Error/destructive color
- **vendaSand** - Default background
- **vendaWhite** - Card/container background
- **vendaInk** - Text color
- **vendaInkMid/Lite** - Secondary text
- **vendaLine** - Borders

All colors automatically support light and dark mode.

### Semantic Color Usage
- **Primary actions**: vendaForest
- **Secondary actions**: vendaOchre or ghost style
- **Destructive/danger**: vendaEmber
- **Backgrounds**: vendaSand (screens), vendaWhite (cards)
- **Text**: vendaInk (primary), vendaInkMid (secondary), vendaInkLt (tertiary)
- **Borders**: vendaLine

---

## Shadows & Elevation

Use the shadow system to indicate depth:

```swift
.shadow(
    color: Color.black.opacity(0.05),
    radius: DesignSystem.Shadow.subtle.radius,
    x: 0,
    y: DesignSystem.Shadow.subtle.y
)
```

### Elevation Levels
- **None**: No shadow
- **Subtle**: 4pt blur, 2pt offset (quiet elements)
- **Default**: 8pt blur, 4pt offset (standard cards)
- **Elevated**: 12pt blur, 6pt offset (prominent elements)

---

## Core Components

### VendaButton
Primary call-to-action button with multiple styles and sizes.

**Styles**: primary, danger, ghost, secondary, flat  
**Sizes**: large (52pt), medium (44pt), small (40pt)

**Features**:
- Loading state
- Disabled state
- Icon support
- Accessibility labels

**Usage**:
```swift
VendaButton(
    title: "Save",
    action: { /* action */ },
    style: .primary,
    size: .large,
    isLoading: false,
    icon: "checkmark"
)
```

### VendaCard
Container for content with optional accent bar and elevation.

**Usage**:
```swift
VendaCard(
    accentColor: .vendaForest,
    elevation: .default_
) {
    Text("Card content")
}
```

### VendaTextField
Unified text input with error states and helpers.

**Usage**:
```swift
VendaTextField(
    label: "Email",
    placeholder: "your@email.com",
    text: $email,
    errorMessage: emailError
)
```

### VendaNumberField
Numeric input for prices and quantities.

**Usage**:
```swift
VendaNumberField(
    label: "Price",
    placeholder: "0.00",
    value: $price
)
```

### SearchField
Unified search input component.

**Usage**:
```swift
SearchField(text: $searchTerm, placeholder: "Search")
```

### VendaBadge  
Versatile badge for tags, statuses, and labels.

**Usage**:
```swift
VendaBadge(title: "New", style: .primary, size: .medium)
PaymentMethodBadge(method: "Cash")
StatusBadge(status: "Active")
```

### State Components
- **SkeletonCard**: Loading placeholder
- **LoadingOverlay**: Full-screen loading
- **ErrorStateCard**: Error display
- **SuccessStateCard**: Confirmation
- **ToastNotification**: Quick feedback (success, error, warning, info)

**Usage**:
```swift
ErrorStateCard(
    title: "Error occurred",
    message: "Please try again",
    actionTitle: "Retry",
    action: { /* retry */ }
)
```

---

## Layout Patterns

### Screen Padding
Always use `DesignSystem.Spacing.lg` (16pt) for horizontal padding:
```swift
.padding(.horizontal, DesignSystem.Spacing.lg)
```

### Section Spacing
Use `DesignSystem.Spacing.xl` (24pt) between major sections:
```swift
VStack(spacing: DesignSystem.Spacing.xl) { ... }
```

### Grid Spacing
Use `DesignSystem.Spacing.md` (12pt) for grid items:
```swift
LazyVGrid(
    columns: [GridItem(.flexible()), GridItem(.flexible())],
    spacing: DesignSystem.Spacing.md
) { ... }
```

---

## Accessibility

### Requirements
1. All interactive elements must be at least 44pt (minimum touch target)
2. Text must have sufficient contrast (WCAG AA minimum)
3. All images/icons must have accessibility labels
4. Form labels must be associated with inputs
5. Color should never be the only way to convey information

### Implementation
```swift
// Use accessibility labels
Text("Info")
    .accessibilityLabel("Account information")

// Use semantic headings
Text("Section").accessibilityAddTraits([.isHeader])

// Ensure button text is clear
Button("Save") { ... }
    .accessibilityLabel("Save changes")
    .accessibilityHint("Tap to save your changes")
```

### Macros
Use provided accessibility modifiers:
```swift
// For buttons
.vendaButtonAccessibility(label: "Edit profile")

// For headings
.vendaHeading(level: .h2)

// For accessible text fields
FocusableTextField(
    label: "Email",
    text: $email,
    placeholder: "your@email.com"
)
```

---

## Do's and Don'ts

### ✅ DO
- Use `DesignSystem` constants everywhere
- Combine small components into larger ones
- Use provided typography scale
- Apply accessibility labels consistently
- Test on multiple screen sizes
- Use vendaCustomComponents  
- Follow the spacing rhythm
- Use semantic colors

### ❌ DON'T
- Hardcode spacing values (use `DesignSystem.Spacing.*`)
- Hardcode font sizes (use `DesignSystem.Typography.*`)
- Hardcode corner radii (use `DesignSystem.Radius.*`)
- Create new component styles without design review
- Mix custom shadows with elevation system
- Ignore accessibility requirements
- Use colors outside the defined palette
- Create new button or input styles (extend existing ones)

---

## Migration Guide

If you find old code using hardcoded values, migrate it:

**Before:**
```swift
Text("Hello")
    .font(.system(size: 18, weight: .semibold))
    .padding(16)
```

**After:**
```swift
Text("Hello")
    .font(DesignSystem.Typography.h4)
    .padding(DesignSystem.Spacing.lg)
```

---

## Questions?

If something isn't clear or you need a new pattern, please document it in the design system first before implementing. This ensures consistency and helps future developers.

---

**Last Updated**: March 2026  
**Design System Version**: 1.0
