// Written by AI on 2026.11.18 by model claude fable 5.2.
// Apple's own map for a region, as the app would show it under the rain, at 2x. Usage:
//   snap <lat> <lon> <width km> <width pt> <height pt> <dark|light> <out.png>
import MapKit
import AppKit

let a = CommandLine.arguments
guard a.count == 8, let lat = Double(a[1]), let lon = Double(a[2]), let km = Double(a[3]),
      let w = Double(a[4]), let h = Double(a[5]) else { fputs("usage\n", stderr); exit(2) }
_ = NSApplication.shared
let options = MKMapSnapshotter.Options()
let centre = CLLocationCoordinate2D(latitude: lat, longitude: lon)
options.region = MKCoordinateRegion(center: centre, latitudinalMeters: km * 1000 * h / w, longitudinalMeters: km * 1000)
options.size = NSSize(width: w, height: h)
options.appearance = NSAppearance(named: a[6] == "dark" ? .darkAqua : .aqua)
let config = MKStandardMapConfiguration(emphasisStyle: .muted)
config.pointOfInterestFilter = .excludingAll
options.preferredConfiguration = config
let snapshotter = MKMapSnapshotter(options: options)
snapshotter.start { snapshot, error in
    guard let snapshot else { fputs("failed: \(String(describing: error))\n", stderr); exit(1) }
    let image = snapshot.image
    guard let cg = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { exit(1) }
    let rep = NSBitmapImageRep(cgImage: cg)
    guard let png = rep.representation(using: .png, properties: [:]) else { exit(1) }
    try! png.write(to: URL(fileURLWithPath: a[7]))
    let nw = snapshot.point(for: centre)
    let east = snapshot.point(for: CLLocationCoordinate2D(latitude: lat, longitude: lon + 0.1))
    // The map is Web Mercator, so the centre and the points per degree of longitude place every pixel.
    print("{\"pixels\":[\(rep.pixelsWide),\(rep.pixelsHigh)],\"centre\":[\(nw.x),\(nw.y)],\"ptPerDegLon\":\((east.x - nw.x) / 0.1)}")
    exit(0)
}
RunLoop.main.run()
