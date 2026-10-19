import AppKit

let output = URL(fileURLWithPath: CommandLine.arguments[1])
let image = NSImage(size: NSSize(width: 1024, height: 1024))
image.lockFocus()
let background = NSBezierPath(roundedRect: NSRect(x: 64, y: 64, width: 896, height: 896),
                              xRadius: 204, yRadius: 204)
NSGradient(starting: NSColor(calibratedRed: 0.22, green: 0.24, blue: 0.38, alpha: 1),
           ending: NSColor(calibratedRed: 0.075, green: 0.085, blue: 0.16, alpha: 1))!
    .draw(in: background, angle: -70)
let moon = NSBezierPath()
moon.move(to: NSPoint(x: 603, y: 800))
moon.curve(to: NSPoint(x: 603, y: 224),
           controlPoint1: NSPoint(x: 206, y: 883), controlPoint2: NSPoint(x: 206, y: 141))
moon.curve(to: NSPoint(x: 603, y: 800),
           controlPoint1: NSPoint(x: 365, y: 342), controlPoint2: NSPoint(x: 365, y: 682))
NSGradient(starting: NSColor(calibratedRed: 0.96, green: 0.92, blue: 0.79, alpha: 1),
           ending: NSColor(calibratedRed: 0.72, green: 0.78, blue: 0.90, alpha: 1))!
    .draw(in: moon, angle: -50)
let star = NSBezierPath()
star.move(to: NSPoint(x: 711, y: 690))
star.line(to: NSPoint(x: 731, y: 637))
star.line(to: NSPoint(x: 784, y: 617))
star.line(to: NSPoint(x: 731, y: 597))
star.line(to: NSPoint(x: 711, y: 544))
star.line(to: NSPoint(x: 691, y: 597))
star.line(to: NSPoint(x: 638, y: 617))
star.line(to: NSPoint(x: 691, y: 637))
star.close()
NSColor(calibratedRed: 0.94, green: 0.91, blue: 0.82, alpha: 1).setFill()
star.fill()
image.unlockFocus()
let bitmap = NSBitmapImageRep(data: image.tiffRepresentation!)!
try bitmap.representation(using: .png, properties: [:])!.write(to: output)
