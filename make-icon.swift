#!/usr/bin/env swift
//
// Generates AppIcon.icns for NiCoLpy: a clipboard motif on a rounded
// blue-gradient tile, drawn entirely with CoreGraphics so no design assets are
// needed. Produces all required iconset sizes and runs `iconutil`.
//
import AppKit

// MARK: - Drawing

func drawIcon(size: CGFloat) -> NSImage {
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()
    guard let ctx = NSGraphicsContext.current?.cgContext else {
        image.unlockFocus()
        return image
    }

    let rect = CGRect(x: 0, y: 0, width: size, height: size)

    // Rounded-rect background with a vertical gradient.
    let corner = size * 0.2237 // matches macOS icon curvature
    let bgPath = NSBezierPath(roundedRect: rect, xRadius: corner, yRadius: corner)
    bgPath.addClip()

    let colors = [
        NSColor(calibratedRed: 0.30, green: 0.55, blue: 0.98, alpha: 1).cgColor,
        NSColor(calibratedRed: 0.16, green: 0.36, blue: 0.85, alpha: 1).cgColor
    ] as CFArray
    let space = CGColorSpaceCreateDeviceRGB()
    if let gradient = CGGradient(colorsSpace: space, colors: colors, locations: [0, 1]) {
        ctx.drawLinearGradient(gradient,
                               start: CGPoint(x: 0, y: size),
                               end: CGPoint(x: 0, y: 0),
                               options: [])
    }

    // Clipboard geometry (centered).
    let boardW = size * 0.46
    let boardH = size * 0.56
    let boardX = (size - boardW) / 2
    let boardY = (size - boardH) / 2 - size * 0.01
    let boardRect = CGRect(x: boardX, y: boardY, width: boardW, height: boardH)
    let boardCorner = size * 0.05

    // Soft shadow under the board.
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -size * 0.012),
                  blur: size * 0.03,
                  color: NSColor.black.withAlphaComponent(0.25).cgColor)

    // Back card (the "stack" hint).
    let backOffset = size * 0.035
    let backRect = boardRect.offsetBy(dx: backOffset, dy: backOffset)
    NSColor.white.withAlphaComponent(0.55).setFill()
    NSBezierPath(roundedRect: backRect, xRadius: boardCorner, yRadius: boardCorner).fill()
    ctx.restoreGState()

    // Front board.
    NSColor.white.setFill()
    NSBezierPath(roundedRect: boardRect, xRadius: boardCorner, yRadius: boardCorner).fill()

    // Clip (the metal clasp at the top).
    let clipW = boardW * 0.34
    let clipH = boardH * 0.12
    let clipX = boardX + (boardW - clipW) / 2
    let clipY = boardY + boardH - clipH * 0.62
    let clipRect = CGRect(x: clipX, y: clipY, width: clipW, height: clipH)
    NSColor(calibratedRed: 0.20, green: 0.42, blue: 0.90, alpha: 1).setFill()
    NSBezierPath(roundedRect: clipRect, xRadius: clipH * 0.35, yRadius: clipH * 0.35).fill()

    // Text lines on the board.
    let lineColor = NSColor(calibratedWhite: 0.0, alpha: 0.16)
    lineColor.setFill()
    let lineX = boardX + boardW * 0.16
    let lineW = boardW * 0.68
    let lineH = boardH * 0.052
    let lineGap = boardH * 0.105
    var lineY = boardY + boardH * 0.60
    for i in 0..<4 {
        let w = (i == 3) ? lineW * 0.6 : lineW
        let lr = CGRect(x: lineX, y: lineY, width: w, height: lineH)
        NSBezierPath(roundedRect: lr, xRadius: lineH / 2, yRadius: lineH / 2).fill()
        lineY -= lineGap
    }

    image.unlockFocus()
    return image
}

func pngData(from image: NSImage, pixelSize: Int) -> Data? {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil,
                              pixelsWide: pixelSize,
                              pixelsHigh: pixelSize,
                              bitsPerSample: 8,
                              samplesPerPixel: 4,
                              hasAlpha: true,
                              isPlanar: false,
                              colorSpaceName: .deviceRGB,
                              bytesPerRow: 0,
                              bitsPerPixel: 0)
    guard let rep else { return nil }
    rep.size = NSSize(width: pixelSize, height: pixelSize)

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    image.draw(in: NSRect(x: 0, y: 0, width: pixelSize, height: pixelSize))
    NSGraphicsContext.restoreGraphicsState()

    return rep.representation(using: .png, properties: [:])
}

// MARK: - Iconset assembly

let fm = FileManager.default
let cwd = fm.currentDirectoryPath
let iconsetDir = "\(cwd)/AppIcon.iconset"
try? fm.removeItem(atPath: iconsetDir)
try! fm.createDirectory(atPath: iconsetDir, withIntermediateDirectories: true)

// (filename, pixel size)
let variants: [(String, Int)] = [
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

for (name, px) in variants {
    let img = drawIcon(size: CGFloat(px))
    if let data = pngData(from: img, pixelSize: px) {
        fm.createFile(atPath: "\(iconsetDir)/\(name)", contents: data)
    }
}

print("Wrote \(variants.count) PNGs to AppIcon.iconset")
