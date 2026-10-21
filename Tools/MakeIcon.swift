import AppKit

@main
struct MakeIcon {
    @MainActor
    static func main() throws {
        let output = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)

        for size in [16, 32, 128, 256, 512] {
            for scale in [1, 2] {
                let pixels = size * scale
                let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels,
                    pixelsHigh: pixels, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                    isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
                bitmap.size = NSSize(width: pixels, height: pixels)
                let context = NSGraphicsContext(bitmapImageRep: bitmap)!
                NSGraphicsContext.saveGraphicsState()
                NSGraphicsContext.current = context
                let image = MoonstoneIcon.image(filled: true, size: CGFloat(pixels))
                image.isTemplate = false
                image.draw(in: NSRect(x: 0, y: 0, width: pixels, height: pixels))
                context.flushGraphics()
                NSGraphicsContext.restoreGraphicsState()

                let suffix = scale == 2 ? "@2x" : ""
                let filename = "icon_\(size)x\(size)\(suffix).png"
                try bitmap.representation(using: .png, properties: [:])!
                    .write(to: output.appendingPathComponent(filename))
            }
        }
    }
}
