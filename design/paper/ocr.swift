import Foundation
import Vision
import AppKit

// Prints each line of text Vision finds: x0 y0 x1 y1 (pixels, top-left origin) and the text.
let langs = CommandLine.arguments[1].split(separator: ",").map(String.init)
for path in CommandLine.arguments.dropFirst(2) {
    guard let image = NSImage(contentsOfFile: path), let cg = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { continue }
    let w = Double(cg.width), h = Double(cg.height)
    let request = VNRecognizeTextRequest()
    request.recognitionLevel = .accurate
    request.usesLanguageCorrection = false
    request.recognitionLanguages = langs
    try VNImageRequestHandler(cgImage: cg).perform([request])
    print("== \(path)")
    for obs in request.results ?? [] {
        guard let top = obs.topCandidates(1).first else { continue }
        let b = obs.boundingBox
        print(String(format: "%.0f %.0f %.0f %.0f\t%@", b.minX * w, (1 - b.maxY) * h, b.maxX * w, (1 - b.minY) * h, top.string))
    }
}
