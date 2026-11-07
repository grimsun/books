import Foundation
import ImageIO

nonisolated struct CoverBitmap: @unchecked Sendable {
    // CGImage is immutable; the same decoded bitmap can be used by multiple views.
    let image: CGImage
}

nonisolated private final class CachedBitmap {
    let bitmap: CoverBitmap
    init(_ bitmap: CoverBitmap) { self.bitmap = bitmap }
}

nonisolated private final class CoverBitmapCache: @unchecked Sendable {
    // NSCache provides synchronized access and automatically responds to memory pressure.
    let images = NSCache<NSString, CachedBitmap>()
    static let buckets = [320, 640, 960, 1200]

    init(memoryLimit: Int) {
        images.totalCostLimit = memoryLimit
        images.countLimit = 128
    }

    static func bucket(_ size: Int) -> Int { buckets.first(where: { $0 >= size }) ?? 1200 }
    static func key(_ url: URL, _ pixels: Int) -> NSString { "\(url.absoluteString)#\(pixels)" as NSString }

    func image(for url: URL, pixels: Int) -> CoverBitmap? {
        for bucket in Self.buckets where bucket >= Self.bucket(pixels) {
            if let cached = images.object(forKey: Self.key(url, bucket)) { return cached.bitmap }
        }
        return nil
    }

    func insert(_ bitmap: CoverBitmap, url: URL, pixels: Int) {
        images.setObject(CachedBitmap(bitmap), forKey: Self.key(url, pixels),
                         cost: bitmap.image.bytesPerRow * bitmap.image.height)
    }
}

actor CoverImagePipeline {
    static let shared = CoverImagePipeline()
    nonisolated private static let bundledCovers: [String: URL] = {
        let names = ["13617691-L", "10618463-L", "8745330-L", "4982600-L", "12840573-L"]
        return Dictionary(uniqueKeysWithValues: names.compactMap { name in
            Bundle.main.url(forResource: name, withExtension: "jpg").map { (name + ".jpg", $0) }
        })
    }()

    nonisolated private let decoded: CoverBitmapCache
    private var session: URLSession?
    private let encoded = NSCache<NSURL, NSData>()
    nonisolated private struct ImageLoad: Sendable {
        let id: UUID
        let url: URL
        let task: Task<CoverBitmap?, Never>
    }
    nonisolated private struct Download: Sendable {
        let id: UUID
        let task: Task<Data?, Never>
    }
    private var inFlight: [String: ImageLoad] = [:]
    private var downloads: [URL: Download] = [:]
    private var readers: [URL: Set<UUID>] = [:]
    private var failures: [URL: Date] = [:]

    init(session: URLSession? = nil, memoryLimit: Int = 24 * 1_024 * 1_024) {
        decoded = CoverBitmapCache(memoryLimit: memoryLimit)
        self.session = session
        encoded.totalCostLimit = 4 * 1_024 * 1_024
        encoded.countLimit = 128
    }

    nonisolated static func sourceURL(for url: URL) -> URL {
        // The bundled seed covers remove all network dependencies from the initial feed.
        if url.host == "covers.openlibrary.org", url.path.hasPrefix("/b/id/"),
           let bundled = bundledCovers[url.lastPathComponent] {
            return bundled
        }
        return url
    }

    nonisolated func cachedImage(for url: URL, maxPixelSize: Int) -> CoverBitmap? {
        decoded.image(for: Self.sourceURL(for: url), pixels: maxPixelSize)
    }

    nonisolated func discardDecodedImages() { decoded.images.removeAllObjects() }

    func image(for originalURL: URL, maxPixelSize: Int) async -> CoverBitmap? {
        guard !Task.isCancelled else { return nil }
        let url = Self.sourceURL(for: originalURL)
        let pixels = CoverBitmapCache.bucket(maxPixelSize)
        if let cached = decoded.image(for: url, pixels: pixels) { return cached }
        if let failure = failures[url], failure > Date() { return nil }
        let reader = UUID()
        readers[url, default: []].insert(reader)
        return await withTaskCancellationHandler {
            let bitmap = await load(url: url, pixels: pixels)
            releaseReader(reader, for: url)
            return bitmap
        } onCancel: {
            Task { await self.releaseReader(reader, for: url) }
        }
    }

    private func load(url: URL, pixels: Int) async -> CoverBitmap? {
        let key = "\(url.absoluteString)#\(pixels)"
        if let existing = inFlight[key] { return await existing.task.value }
        let id = UUID()
        let task = Task { () -> CoverBitmap? in
            let bitmap: CoverBitmap?
            if let data = await self.data(for: url), !Task.isCancelled {
                bitmap = await Task.detached(priority: .utility) {
                    Self.downsample(data, maxPixelSize: pixels)
                }.value
            } else {
                bitmap = nil
            }
            guard !Task.isCancelled else { return nil }
            if let bitmap {
                self.decoded.insert(bitmap, url: url, pixels: pixels)
            } else if !url.isFileURL {
                self.failures = self.failures.filter { $0.value > Date() }
                if self.failures.count < 128 { self.failures[url] = Date().addingTimeInterval(15) }
            }
            return bitmap
        }
        inFlight[key] = ImageLoad(id: id, url: url, task: task)
        let bitmap = await task.value
        if inFlight[key]?.id == id { inFlight[key] = nil }
        return bitmap
    }

    private func releaseReader(_ reader: UUID, for url: URL) {
        guard readers[url]?.remove(reader) != nil, readers[url]?.isEmpty == true else { return }
        readers[url] = nil
        downloads.removeValue(forKey: url)?.task.cancel()
        for (key, load) in inFlight where load.url == url {
            load.task.cancel()
            inFlight[key] = nil
        }
    }

    private func data(for url: URL) async -> Data? {
        if let cached = encoded.object(forKey: url as NSURL) { return cached as Data }
        if let download = downloads[url] { return await download.task.value }
        let id = UUID()
        let session = url.isFileURL ? nil : networkSession()
        let task = Task.detached(priority: .utility) { () -> Data? in
            guard !Task.isCancelled else { return nil }
            if url.isFileURL { return try? Data(contentsOf: url) }
            guard let session else { return nil }
            do {
                #if DEBUG
                await NetworkDiagnostics.shared.recordRequest()
                #endif
                let (data, response) = try await session.data(from: url)
                guard let response = response as? HTTPURLResponse, (200..<300).contains(response.statusCode) else { return nil }
                return data
            } catch { return nil }
        }
        downloads[url] = Download(id: id, task: task)
        let data = await task.value
        if downloads[url]?.id == id { downloads[url] = nil }
        if let data, !Task.isCancelled { encoded.setObject(data as NSData, forKey: url as NSURL, cost: data.count) }
        return data
    }

    private func networkSession() -> URLSession {
        if let session { return session }
        // Build disk/network caches on this worker actor, only when remote data is needed.
        let configuration = URLSessionConfiguration.default
        configuration.urlCache = URLCache(memoryCapacity: 0, diskCapacity: 128 * 1_024 * 1_024)
        configuration.requestCachePolicy = .useProtocolCachePolicy
        configuration.httpMaximumConnectionsPerHost = 4
        configuration.timeoutIntervalForRequest = 15
        let session = URLSession(configuration: configuration)
        self.session = session
        return session
    }

    nonisolated private static func downsample(_ data: Data, maxPixelSize: Int) -> CoverBitmap? {
        autoreleasepool {
            guard let source = CGImageSourceCreateWithData(data as CFData, [kCGImageSourceShouldCache: false] as CFDictionary),
                  let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                    kCGImageSourceCreateThumbnailFromImageAlways: true,
                    kCGImageSourceCreateThumbnailWithTransform: true,
                    kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
                    kCGImageSourceShouldCacheImmediately: true
                  ] as CFDictionary) else { return nil }
            return CoverBitmap(image: image)
        }
    }
}
