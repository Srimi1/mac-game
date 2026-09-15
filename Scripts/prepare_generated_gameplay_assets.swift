import AppKit
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

struct CropJob {
    let source: String
    let rectangle: CGRect
    let output: String
    let maximumDimension: Int
}

let arguments = CommandLine.arguments
guard arguments.count == 5 else {
    fputs("usage: prepare_generated_gameplay_assets.swift <block-sheet.png> <ball.png> <paddle.png> <output-directory>\n", stderr)
    exit(64)
}

let blockSheet = arguments[1]
let ballSource = arguments[2]
let paddleSource = arguments[3]
let outputDirectory = arguments[4]
try FileManager.default.createDirectory(atPath: outputDirectory, withIntermediateDirectories: true)

let jobs = [
    CropJob(source: blockSheet, rectangle: CGRect(x: 20, y: 185, width: 370, height: 285), output: "brick-rounded.png", maximumDimension: 512),
    CropJob(source: blockSheet, rectangle: CGRect(x: 405, y: 185, width: 330, height: 285), output: "brick-capsule.png", maximumDimension: 512),
    CropJob(source: blockSheet, rectangle: CGRect(x: 745, y: 105, width: 305, height: 425), output: "brick-diamond.png", maximumDimension: 512),
    CropJob(source: blockSheet, rectangle: CGRect(x: 1085, y: 135, width: 285, height: 385), output: "brick-hexagon.png", maximumDimension: 512),
    CropJob(source: blockSheet, rectangle: CGRect(x: 1400, y: 120, width: 275, height: 395), output: "brick-triangle.png", maximumDimension: 512),
    CropJob(source: blockSheet, rectangle: CGRect(x: 1690, y: 180, width: 460, height: 300), output: "brick-obstacle.png", maximumDimension: 512),
    CropJob(source: ballSource, rectangle: CGRect(x: 300, y: 285, width: 685, height: 685), output: "ball-energy.png", maximumDimension: 256),
    CropJob(source: paddleSource, rectangle: CGRect(x: 120, y: 330, width: 1_600, height: 250), output: "paddle-launcher.png", maximumDimension: 1_024)
]

func load(_ path: String) throws -> CGImage {
    let url = URL(fileURLWithPath: path) as CFURL
    guard let source = CGImageSourceCreateWithURL(url, nil),
          let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
        throw NSError(domain: "AssetCrop", code: 1, userInfo: [NSLocalizedDescriptionKey: "Unable to read \(path)"])
    }
    return image
}

func resized(_ image: CGImage, maximumDimension: Int) throws -> CGImage {
    let scale = min(1, CGFloat(maximumDimension) / CGFloat(max(image.width, image.height)))
    let width = max(1, Int(CGFloat(image.width) * scale))
    let height = max(1, Int(CGFloat(image.height) * scale))
    guard let context = CGContext(
        data: nil,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else {
        throw NSError(domain: "AssetCrop", code: 2, userInfo: [NSLocalizedDescriptionKey: "Unable to create image context"])
    }
    context.interpolationQuality = .high
    context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
    guard let output = context.makeImage() else {
        throw NSError(domain: "AssetCrop", code: 3, userInfo: [NSLocalizedDescriptionKey: "Unable to create output image"])
    }
    return output
}

for job in jobs {
    let source = try load(job.source)
    guard let crop = source.cropping(to: job.rectangle) else {
        throw NSError(domain: "AssetCrop", code: 4, userInfo: [NSLocalizedDescriptionKey: "Invalid crop for \(job.output)"])
    }
    let image = try resized(crop, maximumDimension: job.maximumDimension)
    let destinationURL = URL(fileURLWithPath: outputDirectory).appendingPathComponent(job.output) as CFURL
    guard let destination = CGImageDestinationCreateWithURL(destinationURL, UTType.png.identifier as CFString, 1, nil) else {
        throw NSError(domain: "AssetCrop", code: 5, userInfo: [NSLocalizedDescriptionKey: "Unable to create \(job.output)"])
    }
    CGImageDestinationAddImage(destination, image, nil)
    guard CGImageDestinationFinalize(destination) else {
        throw NSError(domain: "AssetCrop", code: 6, userInfo: [NSLocalizedDescriptionKey: "Unable to write \(job.output)"])
    }
}
