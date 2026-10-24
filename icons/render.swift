// render: rasterize an SVG to a square PNG with AppKit (no extra tools needed).
//
//   render <in.svg> <out.png> <px> [#rrggbb background, for previews]

import AppKit

let args = CommandLine.arguments
guard args.count >= 4, let px = Int(args[3]) else {
    print("usage: render <in.svg> <out.png> <px> [#rrggbb]")
    exit(2)
}
guard let image = NSImage(contentsOfFile: args[1]) else {
    print("could not load \(args[1])")
    exit(1)
}

let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px, bitsPerSample: 8,
                           samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                           colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
rep.size = NSSize(width: px, height: px)
let rect = NSRect(x: 0, y: 0, width: px, height: px)

NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
if args.count > 4, let hex = UInt32(args[4].dropFirst(), radix: 16) {
    NSColor(red: CGFloat(hex >> 16 & 0xff) / 255, green: CGFloat(hex >> 8 & 0xff) / 255,
            blue: CGFloat(hex & 0xff) / 255, alpha: 1).setFill()
    rect.fill()
}
image.draw(in: rect)
NSGraphicsContext.restoreGraphicsState()

try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: args[2]))
