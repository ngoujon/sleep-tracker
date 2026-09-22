import AppKit
import CoreGraphics

let size = 1024
let rep = NSBitmapImageRep(
    bitmapDataPlanes: nil,
    pixelsWide: size,
    pixelsHigh: size,
    bitsPerSample: 8,
    samplesPerPixel: 4,
    hasAlpha: true,
    isPlanar: false,
    colorSpaceName: .deviceRGB,
    bytesPerRow: 0,
    bitsPerPixel: 0
)!

NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
let ctx = NSGraphicsContext.current!.cgContext

let rect = CGRect(x: 0, y: 0, width: size, height: size)

// Background: rounded square, dark indigo -> navy vertical gradient (macOS "squircle"-ish radius).
let cornerRadius = CGFloat(size) * 0.225
let bgPath = CGPath(roundedRect: rect, cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)
ctx.addPath(bgPath)
ctx.clip()

let colors = [
    CGColor(red: 0.09, green: 0.10, blue: 0.28, alpha: 1),
    CGColor(red: 0.19, green: 0.16, blue: 0.46, alpha: 1)
] as CFArray
let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 1])!
ctx.drawLinearGradient(gradient, start: CGPoint(x: 0, y: size), end: CGPoint(x: size, y: 0), options: [])

// Soft stars.
ctx.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.55))
let stars: [(CGFloat, CGFloat, CGFloat)] = [
    (0.74, 0.80, 10), (0.82, 0.68, 6), (0.68, 0.86, 5), (0.86, 0.58, 7), (0.22, 0.78, 6)
]
for (sx, sy, r) in stars {
    let starRect = CGRect(x: CGFloat(size) * sx - r/2, y: CGFloat(size) * sy - r/2, width: r, height: r)
    ctx.fillEllipse(in: starRect)
}

// Crescent moon: big circle minus offset circle.
ctx.setFillColor(CGColor(red: 0.98, green: 0.96, blue: 0.88, alpha: 1))
let moonCenter = CGPoint(x: CGFloat(size) * 0.42, y: CGFloat(size) * 0.58)
let moonRadius = CGFloat(size) * 0.26
ctx.saveGState()
let moonPath = CGMutablePath()
moonPath.addArc(center: moonCenter, radius: moonRadius, startAngle: 0, endAngle: .pi * 2, clockwise: false)
ctx.addPath(moonPath)
ctx.clip()
ctx.fillEllipse(in: CGRect(x: moonCenter.x - moonRadius, y: moonCenter.y - moonRadius, width: moonRadius * 2, height: moonRadius * 2))
// bite out of the moon with the background gradient color, offset up-right, to form a crescent.
ctx.setFillColor(CGColor(red: 0.14, green: 0.13, blue: 0.37, alpha: 1))
let biteCenter = CGPoint(x: moonCenter.x + moonRadius * 0.62, y: moonCenter.y + moonRadius * 0.5)
ctx.fillEllipse(in: CGRect(x: biteCenter.x - moonRadius, y: biteCenter.y - moonRadius, width: moonRadius * 2, height: moonRadius * 2))
ctx.restoreGState()

// Small analytics bars (score/analysis motif) bottom-right, rounded caps, ascending heights.
let barColor = CGColor(red: 0.55, green: 0.78, blue: 1.0, alpha: 0.95)
ctx.setFillColor(barColor)
let barWidth = CGFloat(size) * 0.07
let barGap = CGFloat(size) * 0.045
let baseY = CGFloat(size) * 0.22
let heights: [CGFloat] = [0.10, 0.16, 0.23]
var x = CGFloat(size) * 0.60
for h in heights {
    let barRect = CGRect(x: x, y: baseY, width: barWidth, height: CGFloat(size) * h)
    let path = CGPath(roundedRect: barRect, cornerWidth: barWidth/2, cornerHeight: barWidth/2, transform: nil)
    ctx.addPath(path)
    ctx.fillPath()
    x += barWidth + barGap
}

NSGraphicsContext.restoreGraphicsState()

let pngData = rep.representation(using: .png, properties: [:])!
let outURL = URL(fileURLWithPath: CommandLine.arguments[1])
try! pngData.write(to: outURL)
print("wrote \(outURL.path)")
