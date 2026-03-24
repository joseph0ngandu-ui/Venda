# Venda Design System - Quick Reference

## Spacing (use these, not hardcoded values)
```swift
DesignSystem.Spacing.xs    // 4pt
DesignSystem.Spacing.sm    // 8pt
DesignSystem.Spacing.md    // 12pt - default between elements
DesignSystem.Spacing.lg    // 16pt - standard padding/margins
DesignSystem.Spacing.xl    // 24pt - section spacing
DesignSystem.Spacing.xxl   // 32pt
DesignSystem.Spacing.xxxl  // 40pt - major sections
```

## Typography (use these, not .system())
```swift
DesignSystem.Typography.h1      // 28pt Bold - Main titles
DesignSystem.Typography.h2      // 24pt Semibold - Section headers
DesignSystem.Typography.h3      // 20pt Semibold - Subsection
DesignSystem.Typography.h4      // 18pt Semibold - Card titles
DesignSystem.Typography.body    // 16pt Regular - Body text
DesignSystem.Typography.bodySemibold
DesignSystem.Typography.bodyMedium
DesignSystem.Typography.bodySmall  // 14pt Regular
DesignSystem.Typography.label      // 12pt Semibold - Form labels
DesignSystem.Typography.caption    // 11pt Medium
DesignSystem.Typography.captionSmall
DesignSystem.Typography.button     // 15pt Semibold
```

## Corner Radius
```swift
DesignSystem.Radius.sm      // 8pt - buttons, badges
DesignSystem.Radius.md      // 12pt - cards, inputs (default)
DesignSystem.Radius.lg      // 16pt - modals
DesignSystem.Radius.xl      // 22pt - tab bar
DesignSystem.Radius.full    // 999pt - pills, circles
```

## Colors (always use these)
```swift
Color.vendaForest      // Primary green
Color.vendaOchre       // Secondary orange/gold
Color.vendaEmber       // Error red
Color.vendaSand        // Screen background (light)
Color.vendaWhite       // Card/container background
Color.vendaInk         // Text (primary)
Color.vendaInkMid      // Text (secondary)
Color.vendaInkLt       // Text (tertiary)
Color.vendaLine        // Borders
```

## Buttons
```swift
// Primary action (default for most)
VendaButton(title: "Save", action: { /* ... */ })

// With styles
VendaButton(title: "Delete", action: { }, style: .danger)
VendaButton(title: "Maybe", action: { }, style: .ghost)

// With size
VendaButton(title: "OK", action: { }, size: .small)

// With icon
VendaButton(title: "Add", action: { }, icon: "plus")

// With loading
VendaButton(title: "Save", action: { }, isLoading: isLoading)
```

## Forms
```swift
// Text input
VendaTextField(
    label: "Email",
    placeholder: "user@example.com",
    text: $email,
    errorMessage: errorText
)

// Number input
VendaNumberField(
    label: "Price",
    placeholder: "0.00",
    value: $price
)

// Password
VendaPasswordField(
    label: "Password",
    placeholder: "••••••••",
    text: $password
)
```

## Cards
```swift
// Default card
VendaCard {
    Text("Content")
}

// With accent bar and elevation
VendaCard(
    accentColor: .vendaForest,
    elevation: .elevated
) {
    Text("Important content")
}
```

## Badges
```swift
// Generic badge
VendaBadge(title: "New", style: .primary, size: .medium)

// Payment method
PaymentMethodBadge(method: "Cash")
PaymentMethodBadge(method: "Mobile Money")

// Status
StatusBadge(status: "Active")
StatusBadge(status: "Pending")
```

## State Components
```swift
// Loading
LoadingOverlay(message: "Processing...")

// Error
ErrorStateCard(
    title: "Error",
    message: "Something went wrong",
    actionTitle: "Retry",
    action: { /* retry */ }
)

// Success
SuccessStateCard(
    title: "Success!",
    message: "Saved successfully"
)

// Toast
ToastNotification(
    message: "Item added",
    type: .success
)
```

## Search
```swift
SearchField(text: $searchTerm, placeholder: "Search...")
```

## Accessibility
```swift
// Label interactive elements
.vendaButtonAccessibility(label: "Save changes")

// Mark headings
Text("Title").vendaHeading(level: .h2)

// Add hints
.accessibilityLabel("Save")
.accessibilityHint("Tap to save your changes")

// Ensure minimum touch size
.minimumTouchTarget()  // 44pt minimum

// Semantic structure
AccessibleList(
    items: items,
    content: { item in /* ... */ },
    listLabel: "Item list"
)
```

## Layouts
```swift
// Standard screen padding
.padding(.horizontal, DesignSystem.Spacing.lg)

// Section spacing
VStack(spacing: DesignSystem.Spacing.xl) { /* ... */ }

// Grid
LazyVGrid(
    columns: [
        GridItem(.flexible()),
        GridItem(.flexible())
    ],
    spacing: DesignSystem.Spacing.md
) { /* ... */ }
```

## DO'S ✅
- Use `DesignSystem.*` constants everywhere
- Test on real devices for touch targets
- Add accessibility labels
- Use provided components
- Follow the spacing system
- Check color contrast
- Support loading states

## DON'Ts ❌
- DON'T hardcode: `.padding(16)` → use `DesignSystem.Spacing.lg`
- DON'T hardcode: `.font(.system(size: 18))` → use `DesignSystem.Typography.h4`
- DON'T create button styles → extend VendaButton
- DON'T ignore accessibility → always add labels
- DON'T mix colors → use palette only
- DON'T create new components → extend existing ones

## Layout Examples

### Header
```swift
VStack(spacing: DesignSystem.Spacing.md) {
    Text("Title").font(DesignSystem.Typography.h2)
    Text("Subtitle").font(DesignSystem.Typography.bodySmall)
}
.padding(.horizontal, DesignSystem.Spacing.lg)
.padding(.top, DesignSystem.Spacing.md)
```

### Section with Cards
```swift
VStack(spacing: DesignSystem.Spacing.lg) {
    Text("Section").font(DesignSystem.Typography.h3)
    VStack(spacing: DesignSystem.Spacing.md) {
        ForEach(items) { item in
            VendaCard { /* item */ }
        }
    }
}
.padding(DesignSystem.Spacing.lg)
```

### Empty State
```swift
EmptyStateCard(
    icon: "cart",
    title: "No items",
    message: "Your cart is empty. Add some items!",
    actionTitle: "Start shopping",
    action: { /* navigate */ }
)
```

---

**Need help?** See `DESIGN_SYSTEM.md` for comprehensive documentation  
**Questions?** Chat with the design team or update the design system first
