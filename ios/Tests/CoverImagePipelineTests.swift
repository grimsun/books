import Foundation
import CoreGraphics
import ImageIO
import Testing
@testable import BookflowCore

struct CoverImagePipelineTests {
    @Test func downsamplesLargeCoverAndReusesDecodedBitmap() async throws {
        let url = try makeCover()
        defer { try? FileManager.default.removeItem(at: url) }
        let pipeline = CoverImagePipeline()
        let first = try #require(await pipeline.image(for: url, maxPixelSize: 300))
        #expect(max(first.image.width, first.image.height) <= 320)
        #expect(first.image.height > first.image.width)
        // Sizes in the same bucket share one decoded bitmap, even if the file disappears.
        try FileManager.default.removeItem(at: url)
        let second = try #require(await pipeline.image(for: url, maxPixelSize: 310))
        #expect(first.image === second.image)
    }

    @Test func concurrentReadersShareDecodeAndCancellationDoesNotBreakOtherReaders() async throws {
        let url = try makeCover()
        defer { try? FileManager.default.removeItem(at: url) }
        let pipeline = CoverImagePipeline()
        let cancelled = Task { await pipeline.image(for: url, maxPixelSize: 300) }
        cancelled.cancel()
        async let a = pipeline.image(for: url, maxPixelSize: 300)
        async let b = pipeline.image(for: url, maxPixelSize: 300)
        let (first, second) = await (a, b)
        #expect(try #require(first).image === #require(second).image)
        _ = await cancelled.value
    }

    @Test func invalidImageDoesNotPoisonCache() async throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: url) }
        try Data("not an image".utf8).write(to: url)
        let pipeline = CoverImagePipeline()
        #expect(await pipeline.image(for: url, maxPixelSize: 100) == nil)
    }

    @Test func smallerCardsReuseLargerBitmapSynchronouslyAndMemoryCanBeReleased() async throws {
        let url = try makeCover()
        defer { try? FileManager.default.removeItem(at: url) }
        let pipeline = CoverImagePipeline()
        let large = try #require(await pipeline.image(for: url, maxPixelSize: 600))
        let small = try #require(pipeline.cachedImage(for: url, maxPixelSize: 250))
        #expect(large.image === small.image)
        #expect(try #require(await pipeline.image(for: url, maxPixelSize: 250)).image === large.image)
        pipeline.discardDecodedImages()
        #expect(pipeline.cachedImage(for: url, maxPixelSize: 250) == nil)
        // Compressed bytes survive decoded-image eviction; no second file read is needed.
        try FileManager.default.removeItem(at: url)
        #expect(await pipeline.image(for: url, maxPixelSize: 600) != nil)
    }

    private func makeCover() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".jpg")
        let context = try #require(CGContext(data: nil, width: 1600, height: 2400, bitsPerComponent: 8,
                                            bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
                                            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue))
        context.setFillColor(CGColor(red: 0.2, green: 0.4, blue: 0.3, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: 1600, height: 2400))
        let destination = try #require(CGImageDestinationCreateWithURL(url as CFURL, "public.jpeg" as CFString, 1, nil))
        CGImageDestinationAddImage(destination, try #require(context.makeImage()), nil)
        #expect(CGImageDestinationFinalize(destination))
        return url
    }
}
