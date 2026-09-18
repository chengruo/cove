import AppKit
import CoreGraphics
import CoreText
import Foundation

// Helper to save NSBitmapImageRep to PNG
func saveToPNG(image: NSImage, targetURL: URL) {
    guard let tiffData = image.tiffRepresentation,
          let rep = NSBitmapImageRep(data: tiffData),
          let pngData = rep.representation(using: .png, properties: [:]) else {
        fatalError("Failed to convert image to PNG at \(targetURL)")
    }
    try! pngData.write(to: targetURL)
    print(" Saved: \(targetURL.path)")
}

// MARK: - 1. Render Logo (1024x1024)
func renderLogo(size: CGFloat = 1024) -> NSImage {
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()
    let ctx = NSGraphicsContext.current!.cgContext

    // 1. Transparent background
    ctx.clear(CGRect(x: 0, y: 0, width: size, height: size))

    // 2. Icon rounded squircle dimensions (Standard macOS squircle ratio)
    let margin: CGFloat = size * 0.1
    let iconSize: CGFloat = size - (margin * 2)
    let iconRect = CGRect(x: margin, y: margin, width: iconSize, height: iconSize)
    let cornerRadius: CGFloat = iconSize * 0.224 // Apple standard squircle radius

    // Drop shadow
    ctx.saveGState()
    ctx.setShadow(
        offset: CGSize(width: 0, height: -size * 0.03),
        blur: size * 0.06,
        color: NSColor.black.withAlphaComponent(0.45).cgColor
    )
    let squirclePath = NSBezierPath(roundedRect: iconRect, xRadius: cornerRadius, yRadius: cornerRadius)
    NSColor.black.setFill()
    squirclePath.fill()
    ctx.restoreGState()

    // Base background gradient: Deep oceanic midnight to glowing sapphire teal
    ctx.saveGState()
    squirclePath.addClip()

    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let gradientColors = [
        NSColor(red: 0.04, green: 0.07, blue: 0.16, alpha: 1.0).cgColor, // Deepest Midnight
        NSColor(red: 0.06, green: 0.18, blue: 0.32, alpha: 1.0).cgColor, // Oceanic Indigo
        NSColor(red: 0.03, green: 0.32, blue: 0.48, alpha: 1.0).cgColor, // Deep Cyan Cove
        NSColor(red: 0.00, green: 0.58, blue: 0.72, alpha: 1.0).cgColor  // Vibrant Turquoise
    ] as CFArray
    let gradientLocations: [CGFloat] = [0.0, 0.4, 0.75, 1.0]
    let gradient = CGGradient(colorsSpace: colorSpace, colors: gradientColors, locations: gradientLocations)!

    ctx.drawLinearGradient(
        gradient,
        start: CGPoint(x: iconRect.midX, y: iconRect.maxY),
        end: CGPoint(x: iconRect.midX, y: iconRect.minY),
        options: []
    )

    // Inner subtle radial glow at bottom (The "Cove" light)
    let glowColors = [
        NSColor(red: 0.00, green: 0.85, blue: 1.0, alpha: 0.35).cgColor,
        NSColor(red: 0.00, green: 0.60, blue: 0.90, alpha: 0.0).cgColor
    ] as CFArray
    let glowGradient = CGGradient(colorsSpace: colorSpace, colors: glowColors, locations: [0.0, 1.0])!
    ctx.drawRadialGradient(
        glowGradient,
        startCenter: CGPoint(x: iconRect.midX, y: iconRect.minY + iconSize * 0.2),
        startRadius: 0,
        endCenter: CGPoint(x: iconRect.midX, y: iconRect.minY + iconSize * 0.2),
        endRadius: iconSize * 0.6,
        options: []
    )

    // Inset border stroke (Apple frosted rim)
    ctx.setLineWidth(size * 0.008)
    ctx.setStrokeColor(NSColor.white.withAlphaComponent(0.2).cgColor)
    squirclePath.stroke()

    // 3. Central Artwork: Stylized Menu Bar & Notch "Cove"
    // Top Bar line
    let barY = iconRect.maxY - iconSize * 0.26
    let barHeight = iconSize * 0.075
    let barWidth = iconSize * 0.74
    let barX = iconRect.midX - barWidth / 2
    let barRect = CGRect(x: barX, y: barY, width: barWidth, height: barHeight)

    let barPath = NSBezierPath(roundedRect: barRect, xRadius: barHeight / 2, yRadius: barHeight / 2)
    NSColor.white.withAlphaComponent(0.12).setFill()
    barPath.fill()

    // The Notch Cutout at center of top bar
    let notchWidth = iconSize * 0.24
    let notchHeight = barHeight * 1.55
    let notchX = iconRect.midX - notchWidth / 2
    let notchY = barRect.maxY - notchHeight
    let notchRect = CGRect(x: notchX, y: notchY, width: notchWidth, height: notchHeight)
    let notchPath = NSBezierPath(roundedRect: notchRect, xRadius: iconSize * 0.025, yRadius: iconSize * 0.025)
    NSColor(red: 0.03, green: 0.05, blue: 0.12, alpha: 0.95).setFill()
    notchPath.fill()

    // Camera lens dot inside notch
    let lensRadius = iconSize * 0.014
    let lensCenter = CGPoint(x: iconRect.midX, y: notchY + notchHeight * 0.45)
    let lensPath = NSBezierPath(
        ovalIn: CGRect(x: lensCenter.x - lensRadius, y: lensCenter.y - lensRadius, width: lensRadius * 2, height: lensRadius * 2)
    )
    NSColor(red: 0.15, green: 0.25, blue: 0.45, alpha: 0.8).setFill()
    lensPath.fill()

    // 4. Overflow items emerging from behind notch into the Cove
    // A floating pill below the notch: The Cove Haven
    let covePillWidth = iconSize * 0.62
    let covePillHeight = iconSize * 0.28
    let covePillX = iconRect.midX - covePillWidth / 2
    let covePillY = iconRect.minY + iconSize * 0.26
    let covePillRect = CGRect(x: covePillX, y: covePillY, width: covePillWidth, height: covePillHeight)

    let covePillPath = NSBezierPath(roundedRect: covePillRect, xRadius: iconSize * 0.045, yRadius: iconSize * 0.045)
    // Glassy fill
    NSColor.white.withAlphaComponent(0.15).setFill()
    covePillPath.fill()
    NSColor.white.withAlphaComponent(0.35).setStroke()
    covePillPath.lineWidth = size * 0.006
    covePillPath.stroke()

    // Little glowing app icons / status indicators inside the Cove pill
    let pillItemCount = 4
    let pillSpacing = covePillWidth / CGFloat(pillItemCount + 1)
    let iconColors = [
        NSColor(red: 0.20, green: 0.78, blue: 1.0, alpha: 0.9),  // Cyan
        NSColor(red: 0.35, green: 0.88, blue: 0.55, alpha: 0.9), // Green
        NSColor(red: 1.00, green: 0.65, blue: 0.20, alpha: 0.9), // Amber
        NSColor(red: 0.85, green: 0.45, blue: 1.0, alpha: 0.9)   // Purple
    ]

    for i in 0..<pillItemCount {
        let cx = covePillX + pillSpacing * CGFloat(i + 1)
        let cy = covePillRect.midY
        let r = iconSize * 0.042

        let itemRect = CGRect(x: cx - r, y: cy - r, width: r * 2, height: r * 2)
        let itemPath = NSBezierPath(roundedRect: itemRect, xRadius: r * 0.35, yRadius: r * 0.35)
        iconColors[i].setFill()
        itemPath.fill()

        // Inner highlight
        NSColor.white.withAlphaComponent(0.4).setStroke()
        itemPath.lineWidth = size * 0.003
        itemPath.stroke()
    }

    // Connector beam from Notch to Cove pill (showing retrieval)
    let beamPath = NSBezierPath()
    beamPath.move(to: CGPoint(x: iconRect.midX - notchWidth * 0.3, y: notchY))
    beamPath.line(to: CGPoint(x: iconRect.midX - covePillWidth * 0.25, y: covePillRect.maxY))
    beamPath.line(to: CGPoint(x: iconRect.midX + covePillWidth * 0.25, y: covePillRect.maxY))
    beamPath.line(to: CGPoint(x: iconRect.midX + notchWidth * 0.3, y: notchY))
    beamPath.close()

    let beamColors = [
        NSColor.cyan.withAlphaComponent(0.25).cgColor,
        NSColor.cyan.withAlphaComponent(0.0).cgColor
    ] as CFArray
    let beamGradient = CGGradient(colorsSpace: colorSpace, colors: beamColors, locations: [0.0, 1.0])!
    ctx.saveGState()
    beamPath.addClip()
    ctx.drawLinearGradient(
        beamGradient,
        start: CGPoint(x: iconRect.midX, y: covePillRect.maxY),
        end: CGPoint(x: iconRect.midX, y: notchY),
        options: []
    )
    ctx.restoreGState()

    ctx.restoreGState() // restore squircle clip

    image.unlockFocus()
    return image
}

// MARK: - 2. Render Preview Banner (1600x1000)
func renderPreview(width: CGFloat = 1600, height: CGFloat = 1000) -> NSImage {
    let image = NSImage(size: NSSize(width: width, height: height))
    image.lockFocus()
    let ctx = NSGraphicsContext.current!.cgContext

    let colorSpace = CGColorSpaceCreateDeviceRGB()

    // 1. Dark ambient desktop background
    let bgColors = [
        NSColor(red: 0.07, green: 0.08, blue: 0.14, alpha: 1.0).cgColor,
        NSColor(red: 0.05, green: 0.06, blue: 0.10, alpha: 1.0).cgColor
    ] as CFArray
    let bgGradient = CGGradient(colorsSpace: colorSpace, colors: bgColors, locations: [0.0, 1.0])!
    ctx.drawLinearGradient(bgGradient, start: CGPoint(x: 0, y: height), end: CGPoint(x: width, y: 0), options: [])

    // Ambient wallpaper glows (Apple mesh style)
    func drawMeshGlow(center: CGPoint, radius: CGFloat, color: NSColor) {
        let colors = [color.cgColor, color.withAlphaComponent(0.0).cgColor] as CFArray
        let g = CGGradient(colorsSpace: colorSpace, colors: colors, locations: [0.0, 1.0])!
        ctx.drawRadialGradient(g, startCenter: center, startRadius: 0, endCenter: center, endRadius: radius, options: [])
    }
    drawMeshGlow(center: CGPoint(x: width * 0.25, y: height * 0.75), radius: 550, color: NSColor(red: 0.1, green: 0.3, blue: 0.6, alpha: 0.35))
    drawMeshGlow(center: CGPoint(x: width * 0.8, y: height * 0.6), radius: 600, color: NSColor(red: 0.4, green: 0.15, blue: 0.5, alpha: 0.3))
    drawMeshGlow(center: CGPoint(x: width * 0.5, y: height * 0.25), radius: 500, color: NSColor(red: 0.0, green: 0.5, blue: 0.6, alpha: 0.25))

    // 2. Simulated MacBook Display Bezel & Menu Bar
    let menuBarHeight: CGFloat = 64
    let menuBarY: CGFloat = height - menuBarHeight - 60
    let menuBarWidth: CGFloat = width - 120
    let menuBarX: CGFloat = 60
    let menuBarRect = CGRect(x: menuBarX, y: menuBarY, width: menuBarWidth, height: menuBarHeight)

    // Top screen frame bezel
    let bezelPath = NSBezierPath(
        roundedRect: CGRect(x: menuBarX - 10, y: menuBarY - 10, width: menuBarWidth + 20, height: menuBarHeight + 20),
        xRadius: 16, yRadius: 16
    )
    NSColor(white: 0.12, alpha: 0.8).setFill()
    bezelPath.fill()

    // Menu bar frosted translucent glass
    let menuBarPath = NSBezierPath(roundedRect: menuBarRect, xRadius: 10, yRadius: 10)
    NSColor(white: 0.15, alpha: 0.75).setFill()
    menuBarPath.fill()
    NSColor.white.withAlphaComponent(0.15).setStroke()
    menuBarPath.lineWidth = 1.0
    menuBarPath.stroke()

    // 3. Central Notch Cutout
    let notchWidth: CGFloat = 200
    let notchHeight: CGFloat = menuBarHeight + 6
    let notchX: CGFloat = menuBarRect.midX - notchWidth / 2
    let notchY: CGFloat = menuBarRect.maxY - notchHeight
    let notchRect = CGRect(x: notchX, y: notchY, width: notchWidth, height: notchHeight)
    let notchPath = NSBezierPath(roundedRect: notchRect, xRadius: 14, yRadius: 14)
    NSColor.black.setFill()
    notchPath.fill()

    // Notch Camera
    let camRadius: CGFloat = 6
    let camCenter = CGPoint(x: notchRect.midX, y: notchRect.minY + notchHeight * 0.4)
    let camPath = NSBezierPath(ovalIn: CGRect(x: camCenter.x - camRadius, y: camCenter.y - camRadius, width: camRadius * 2, height: camRadius * 2))
    NSColor(white: 0.15, alpha: 0.9).setFill()
    camPath.fill()

    // Left Menu items: Apple logo, Finder, File, Edit, View
    let textAttrs: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: 15, weight: .medium),
        .foregroundColor: NSColor.white.withAlphaComponent(0.9)
    ]
    let menuTitle = "   Finder   File   Edit   View   Go   Window   Help"
    menuTitle.draw(at: CGPoint(x: menuBarX + 24, y: menuBarY + 22), withAttributes: textAttrs)

    // Right Menu items: Battery, Wi-Fi, Input Source "中", Cove Icon, Control Center, Time
    let rightTextAttrs: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: 14, weight: .regular),
        .foregroundColor: NSColor.white.withAlphaComponent(0.85)
    ]
    "9:41 AM".draw(at: CGPoint(x: menuBarRect.maxX - 90, y: menuBarY + 22), withAttributes: rightTextAttrs)
    "⊚  􀙇  􀛨  中".draw(at: CGPoint(x: menuBarRect.maxX - 220, y: menuBarY + 22), withAttributes: rightTextAttrs)

    // Highlighted Cove Icon in Menu Bar (Right next to input method!)
    let coveIconX = menuBarRect.maxX - 265
    let coveIconY = menuBarY + 14
    let coveIconBadge = CGRect(x: coveIconX, y: coveIconY, width: 36, height: 36)
    let coveBadgePath = NSBezierPath(roundedRect: coveIconBadge, xRadius: 8, yRadius: 8)
    NSColor.systemBlue.withAlphaComponent(0.35).setFill()
    coveBadgePath.fill()
    NSColor.cyan.withAlphaComponent(0.8).setStroke()
    coveBadgePath.lineWidth = 1.5
    coveBadgePath.stroke()

    // Draw mini dock symbol inside badge
    let symbolAttrs: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: 18, weight: .semibold),
        .foregroundColor: NSColor.cyan
    ]
    "􀤂".draw(at: CGPoint(x: coveIconX + 8, y: coveIconY + 8), withAttributes: symbolAttrs)

    // 4. Occluded items behind the Notch (Visual demonstration)
    let occludedTextAttrs: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: 13, weight: .semibold),
        .foregroundColor: NSColor.red.withAlphaComponent(0.8)
    ]
    "✕ Hidden by Notch".draw(at: CGPoint(x: notchX - 150, y: menuBarY + 23), withAttributes: occludedTextAttrs)

    // Arrow pointing to notch
    let arrowPath = NSBezierPath()
    arrowPath.move(to: CGPoint(x: notchX - 25, y: menuBarY + 30))
    arrowPath.line(to: CGPoint(x: notchX - 8, y: menuBarY + 30))
    NSColor.red.withAlphaComponent(0.8).setStroke()
    arrowPath.lineWidth = 2.0
    arrowPath.stroke()

    // 5. The Native Frosted Glass Popover Panel
    let panelWidth: CGFloat = 380
    let panelHeight: CGFloat = 460
    let panelX = coveIconBadge.midX - panelWidth / 2
    let panelY = menuBarY - panelHeight - 16
    let panelRect = CGRect(x: panelX, y: panelY, width: panelWidth, height: panelHeight)

    // Panel Shadow
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -12), blur: 32, color: NSColor.black.withAlphaComponent(0.55).cgColor)
    let panelPath = NSBezierPath(roundedRect: panelRect, xRadius: 16, yRadius: 16)
    NSColor(red: 0.12, green: 0.14, blue: 0.20, alpha: 0.95).setFill()
    panelPath.fill()
    ctx.restoreGState()

    // Frosted border
    NSColor.white.withAlphaComponent(0.18).setStroke()
    panelPath.lineWidth = 1.0
    panelPath.stroke()

    // Panel Header
    let pHeaderY = panelRect.maxY - 50
    let headerTitleAttrs: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: 15, weight: .bold),
        .foregroundColor: NSColor.white
    ]
    "Hidden Menu Bar".draw(at: CGPoint(x: panelX + 20, y: pHeaderY + 12), withAttributes: headerTitleAttrs)

    let headerSubAttrs: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: 12, weight: .regular),
        .foregroundColor: NSColor.systemCyan
    ]
    "4 items hidden by notch".draw(at: CGPoint(x: panelX + 20, y: pHeaderY - 6), withAttributes: headerSubAttrs)

    // Header buttons (Refresh & More)
    let iconBtnAttrs: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: 15, weight: .medium),
        .foregroundColor: NSColor.white.withAlphaComponent(0.7)
    ]
    "↻   ⋯".draw(at: CGPoint(x: panelRect.maxX - 65, y: pHeaderY + 6), withAttributes: iconBtnAttrs)

    // Header divider
    let div1 = NSBezierPath()
    div1.move(to: CGPoint(x: panelX + 16, y: pHeaderY - 14))
    div1.line(to: CGPoint(x: panelRect.maxX - 16, y: pHeaderY - 14))
    NSColor.white.withAlphaComponent(0.1).setStroke()
    div1.lineWidth = 1
    div1.stroke()

    // Status Items List
    struct MockItem {
        let name: String
        let desc: String
        let color: NSColor
        let iconLetter: String
    }
    let mockItems = [
        MockItem(name: "ClashX Meta", desc: "Rule Proxy • Direct", color: NSColor.systemTeal, iconLetter: "⚡"),
        MockItem(name: "PortBar", desc: "Localhost :3000, :8080", color: NSColor.systemBlue, iconLetter: "🌐"),
        MockItem(name: "ChatGPT", desc: "Ready • GPT-4o", color: NSColor.systemGreen, iconLetter: "✦"),
        MockItem(name: "Docker Desktop", desc: "Engine running (3 containers)", color: NSColor.systemIndigo, iconLetter: "🐳")
    ]

    let itemStartY = pHeaderY - 26
    let rowHeight: CGFloat = 68

    for (index, item) in mockItems.enumerated() {
        let rowY = itemStartY - CGFloat(index + 1) * rowHeight
        let rowRect = CGRect(x: panelX + 12, y: rowY + 4, width: panelWidth - 24, height: rowHeight - 8)

        // Hover highlight on first item
        if index == 0 {
            let hoverPath = NSBezierPath(roundedRect: rowRect, xRadius: 10, yRadius: 10)
            NSColor.white.withAlphaComponent(0.12).setFill()
            hoverPath.fill()
            NSColor.cyan.withAlphaComponent(0.3).setStroke()
            hoverPath.lineWidth = 1
            hoverPath.stroke()
        }

        // Icon squircle
        let iconRect = CGRect(x: rowRect.minX + 10, y: rowRect.minY + 10, width: 38, height: 38)
        let iconPath = NSBezierPath(roundedRect: iconRect, xRadius: 9, yRadius: 9)
        item.color.withAlphaComponent(0.25).setFill()
        iconPath.fill()
        item.color.withAlphaComponent(0.6).setStroke()
        iconPath.lineWidth = 1
        iconPath.stroke()

        // Icon Emoji/Letter
        let glyphAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 18),
            .foregroundColor: NSColor.white
        ]
        item.iconLetter.draw(at: CGPoint(x: iconRect.minX + 8, y: iconRect.minY + 8), withAttributes: glyphAttrs)

        // Item Title & Subtitle
        let titleAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 14, weight: .semibold),
            .foregroundColor: NSColor.white
        ]
        item.name.draw(at: CGPoint(x: iconRect.maxX + 12, y: iconRect.minY + 18), withAttributes: titleAttrs)

        let subAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 11, weight: .regular),
            .foregroundColor: NSColor.white.withAlphaComponent(0.55)
        ]
        item.desc.draw(at: CGPoint(x: iconRect.maxX + 12, y: iconRect.minY + 2), withAttributes: subAttrs)

        // Action Trigger indicator / Chevron
        let chevronAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 14, weight: .bold),
            .foregroundColor: NSColor.white.withAlphaComponent(0.4)
        ]
        "›".draw(at: CGPoint(x: rowRect.maxX - 20, y: iconRect.minY + 12), withAttributes: chevronAttrs)
    }

    // Panel Footer
    let footerY = panelRect.minY + 12
    let statusDot = NSBezierPath(ovalIn: CGRect(x: panelX + 20, y: footerY + 8, width: 8, height: 8))
    NSColor.systemGreen.setFill()
    statusDot.fill()

    let footerAttrs: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: 11, weight: .medium),
        .foregroundColor: NSColor.white.withAlphaComponent(0.7)
    ]
    "Notch Active • 0% Idle CPU".draw(at: CGPoint(x: panelX + 34, y: footerY + 5), withAttributes: footerAttrs)

    // Shortcut Pill
    let pillRect = CGRect(x: panelRect.maxX - 70, y: footerY + 4, width: 48, height: 20)
    let pillPath = NSBezierPath(roundedRect: pillRect, xRadius: 5, yRadius: 5)
    NSColor.white.withAlphaComponent(0.12).setFill()
    pillPath.fill()
    let pillAttrs: [NSAttributedString.Key: Any] = [
        .font: NSFont.monospacedSystemFont(ofSize: 11, weight: .bold),
        .foregroundColor: NSColor.white.withAlphaComponent(0.85)
    ]
    "⌃⌥C".draw(at: CGPoint(x: pillRect.minX + 8, y: pillRect.minY + 3), withAttributes: pillAttrs)

    // 6. Marketing Title & Feature Cards on the Left Side
    let titleAttrs: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: 42, weight: .heavy),
        .foregroundColor: NSColor.white
    ]
    "Cove".draw(at: CGPoint(x: 100, y: height - 230), withAttributes: titleAttrs)

    let taglineAttrs: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: 20, weight: .medium),
        .foregroundColor: NSColor.cyan
    ]
    "MacBook Notch Menu Bar Rescue".draw(at: CGPoint(x: 100, y: height - 270), withAttributes: taglineAttrs)

    let descAttrs: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: 15, weight: .regular),
        .foregroundColor: NSColor.white.withAlphaComponent(0.7)
    ]
    let desc = "Pure Native Swift • Zero Polling • Launch at Login • Instant AX Trigger"
    desc.draw(at: CGPoint(x: 100, y: height - 305), withAttributes: descAttrs)

    // Feature Badges
    func drawFeaturePill(at point: CGPoint, title: String, subtitle: String) {
        let pWidth: CGFloat = 360
        let pHeight: CGFloat = 62
        let pRect = CGRect(x: point.x, y: point.y, width: pWidth, height: pHeight)
        let path = NSBezierPath(roundedRect: pRect, xRadius: 12, yRadius: 12)
        NSColor.white.withAlphaComponent(0.06).setFill()
        path.fill()
        NSColor.white.withAlphaComponent(0.12).setStroke()
        path.lineWidth = 1
        path.stroke()

        let tAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 14, weight: .semibold),
            .foregroundColor: NSColor.white
        ]
        title.draw(at: CGPoint(x: point.x + 16, y: point.y + 32), withAttributes: tAttrs)

        let sAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 12, weight: .regular),
            .foregroundColor: NSColor.white.withAlphaComponent(0.6)
        ]
        subtitle.draw(at: CGPoint(x: point.x + 16, y: point.y + 12), withAttributes: sAttrs)
    }

    drawFeaturePill(
        at: CGPoint(x: 100, y: height - 400),
        title: "⚡ Native AXPress Action Trigger",
        subtitle: "Directly trigger original menu bar menus & popovers"
    )
    drawFeaturePill(
        at: CGPoint(x: 100, y: height - 480),
        title: "🎯 Real-Time Notch & Overflow Calculation",
        subtitle: "Official NSScreen APIs for all MacBook models & displays"
    )
    drawFeaturePill(
        at: CGPoint(x: 100, y: height - 560),
        title: "⌨️ Global Hotkey Penetration (⌃⌥C)",
        subtitle: "Summon panel beneath the Notch even if Cove is occluded"
    )
    drawFeaturePill(
        at: CGPoint(x: 100, y: height - 640),
        title: "🚀 Modern Launch at Login (macOS 14+)",
        subtitle: "SMAppService integration with System Settings"
    )

    image.unlockFocus()
    return image
}

// MARK: - Execute Asset Generation
let fileManager = FileManager.default
let currentDir = URL(fileURLWithPath: fileManager.currentDirectoryPath)
let assetsDir = currentDir.appendingPathComponent("Assets")

try? fileManager.createDirectory(at: assetsDir, withIntermediateDirectories: true)

print("🎨 Generating Cove Assets...")

// 1. Generate Logo
let logoImage = renderLogo(size: 1024)
let logoURL = assetsDir.appendingPathComponent("logo.png")
saveToPNG(image: logoImage, targetURL: logoURL)

// 2. Generate Preview Banner
let previewImage = renderPreview(width: 1600, height: 1000)
let previewURL = assetsDir.appendingPathComponent("preview.png")
saveToPNG(image: previewImage, targetURL: previewURL)

// 3. Generate Multi-Resolution AppIcon iconset for macOS
let iconsetDir = assetsDir.appendingPathComponent("AppIcon.iconset")
try? fileManager.createDirectory(at: iconsetDir, withIntermediateDirectories: true)

let iconSizes: [(name: String, size: CGFloat)] = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024)
]

for item in iconSizes {
    let resized = renderLogo(size: item.size)
    let url = iconsetDir.appendingPathComponent(item.name)
    saveToPNG(image: resized, targetURL: url)
}

print("✅ All assets generated successfully!")
