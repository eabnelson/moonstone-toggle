import AppKit

/// The two-stone mark from https://moonstonelamp.com/images/favicon.svg.
/// Both states use the same canvas and geometry to keep the menu bar anchor fixed.
@MainActor
enum MoonstoneIcon {
    static let on = image(filled: true)
    static let off = image(filled: false)

    static func image(filled: Bool, size: CGFloat = 18) -> NSImage {
        let image = NSImage(size: NSSize(width: size, height: size))
        image.lockFocus()
        let scale = size * 0.84 / 935
        func point(_ x: CGFloat, _ y: CGFloat) -> NSPoint {
            NSPoint(x: (size - 884 * scale) / 2 + x * scale,
                    y: (size - 935 * scale) / 2 + (935 - y) * scale)
        }
        let path = NSBezierPath()
        path.move(to: point(392.969, 650))
        path.curve(to: point(669.28, 711.038), controlPoint1: point(488.096, 650), controlPoint2: point(633.34, 663.899))
        path.curve(to: point(461.236, 934.097), controlPoint1: point(720.112, 777.71), controlPoint2: point(648.16, 934.097))
        path.curve(to: point(205.063, 805.838), controlPoint1: point(359.608, 934.097), controlPoint2: point(205.064, 917.367))
        path.curve(to: point(392.969, 650), controlPoint1: point(205.063, 694.309), controlPoint2: point(283.657, 650))
        path.close()
        path.move(to: point(418.971, 0))
        path.curve(to: point(859.479, 202.941), controlPoint1: point(567.428, 0), controlPoint2: point(803.39, 49.8947))
        path.curve(to: point(524.768, 653.063), controlPoint1: point(938.808, 419.402), controlPoint2: point(816.483, 653.062))
        path.curve(to: point(0, 352.363), controlPoint1: point(366.165, 653.063), controlPoint2: point(0, 602.906))
        path.curve(to: point(418.971, 0), controlPoint1: point(0, 40.2467), controlPoint2: point(248.377, 0))
        path.close()
        NSColor.black.set()
        if filled { path.fill() }
        else {
            path.lineWidth = size * 1.15 / 18
            path.lineJoinStyle = .round
            path.stroke()
        }
        image.unlockFocus()
        image.isTemplate = true
        image.accessibilityDescription = "Moonstone"
        return image
    }
}
