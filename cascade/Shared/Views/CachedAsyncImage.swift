import SwiftUI
import UIKit
import CryptoKit

/// Artwork survives lazy-grid view recycling, with disk backing for memory evictions.
@MainActor
final class ArtworkCache {
    static let shared = ArtworkCache()

    private let images = NSCache<NSURL, UIImage>()
    private let loader: ArtworkLoader
    private var downloads: [URL: Task<UIImage, Error>] = [:]

    init(
        directory: URL = URL.cachesDirectory.appendingPathComponent("CascadeArtwork", isDirectory: true),
        sessionConfiguration: URLSessionConfiguration = .ephemeral,
        memoryCapacity: Int = 128 * 1024 * 1024,
        diskCapacity: Int = 512 * 1024 * 1024
    ) {
        images.totalCostLimit = memoryCapacity
        loader = ArtworkLoader(
            directory: directory,
            configuration: sessionConfiguration,
            capacity: diskCapacity
        )
    }

    func cachedImage(for url: URL) -> UIImage? {
        images.object(forKey: url as NSURL)
    }

    func image(for url: URL) async throws -> UIImage {
        if let image = cachedImage(for: url) { return image }
        if let download = downloads[url] { return try await download.value }

        // This shared task intentionally outlives any individual offscreen cell.
        let download = Task<UIImage, Error> {
            defer { downloads[url] = nil }
            let image = try await loader.image(for: url)
            let cost = image.cgImage.map { $0.bytesPerRow * $0.height } ?? 0
            images.setObject(image, forKey: url as NSURL, cost: cost)
            return image
        }
        downloads[url] = download
        return try await download.value
    }
}

/// Keep encoded artwork independently of HTTP cache rules, and keep disk I/O and
/// image decompression off the main actor while scrolling.
private actor ArtworkLoader {
    private let directory: URL
    private let session: URLSession
    private let capacity: Int
    private var diskUsage: Int?

    init(directory: URL, configuration: URLSessionConfiguration, capacity: Int) {
        self.directory = directory
        self.capacity = capacity
        let configuration = configuration.copy() as! URLSessionConfiguration
        configuration.urlCache = nil
        session = URLSession(configuration: configuration)
    }

    func image(for url: URL) async throws -> UIImage {
        // Reconcile files left by previous launches before serving disk hits,
        // including when the configured budget has been reduced.
        if diskUsage == nil { trim() }

        // Include server, credentials, size and image tag in the key. A changed
        // Jellyfin image tag must never reuse the old artwork.
        let key = SHA256.hash(data: Data(url.absoluteString.utf8))
            .map { String(format: "%02x", $0) }.joined()
        let file = directory.appendingPathComponent(key).appendingPathExtension("artwork")
        if let data = try? Data(contentsOf: file) {
            if let image = decode(data) {
                try? FileManager.default.setAttributes([.modificationDate: Date()], ofItemAtPath: file.path)
                return image
            }
            // A damaged entry should be downloaded again, not fail on every visit.
            try? FileManager.default.removeItem(at: file)
            diskUsage = nil
        }

        let request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData)
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        guard let image = decode(data) else { throw URLError(.cannotDecodeContentData) }
        store(data, at: file)
        return image
    }

    private func decode(_ data: Data) -> UIImage? {
        guard let image = UIImage(data: data) else { return nil }
        return image.preparingForDisplay() ?? image
    }

    private func store(_ data: Data, at file: URL) {
        guard data.count <= capacity else { return }
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let previousSize = (try? file.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
            try data.write(to: file, options: .atomic)
            if let usage = diskUsage {
                diskUsage = usage - previousSize + data.count
            } else {
                diskUsage = cachedFiles().reduce(0) { $0 + $1.size }
            }
            if let usage = diskUsage, usage > capacity { trim() }
        } catch {
            // A full or unavailable cache must not prevent displaying a poster.
            diskUsage = nil
        }
    }

    private func cachedFiles() -> [(url: URL, size: Int, date: Date)] {
        let keys: Set<URLResourceKey> = [.fileSizeKey, .contentModificationDateKey]
        let files = (try? FileManager.default.contentsOfDirectory(
            at: directory, includingPropertiesForKeys: Array(keys), options: .skipsHiddenFiles
        )) ?? []
        return files.filter { $0.pathExtension == "artwork" }.compactMap { file in
            guard let values = try? file.resourceValues(forKeys: keys) else { return nil }
            return (file, values.fileSize ?? 0, values.contentModificationDate ?? .distantPast)
        }
    }

    private func trim() {
        let files = cachedFiles().sorted { $0.date < $1.date }
        var usage = files.reduce(0) { $0 + $1.size }
        for file in files where usage > capacity {
            if (try? FileManager.default.removeItem(at: file.url)) != nil {
                usage -= file.size
            }
        }
        diskUsage = usage
    }
}

@MainActor
struct CachedAsyncImage<Content: View>: View {
    let url: URL?
    @ViewBuilder let content: (AsyncImagePhase) -> Content

    @State private var loadedURL: URL?
    @State private var phase: AsyncImagePhase = .empty

    var body: some View {
        content(currentPhase)
            .task(id: url) {
                guard let url else { return }
                do {
                    let image = try await ArtworkCache.shared.image(for: url)
                    try Task.checkCancellation()
                    loadedURL = url
                    phase = .success(Image(uiImage: image))
                } catch {
                    guard !Task.isCancelled else { return }
                    loadedURL = url
                    phase = .failure(error)
                }
            }
    }

    private var currentPhase: AsyncImagePhase {
        // A recreated cell displays a memory hit immediately, without a placeholder flash.
        if let url, let image = ArtworkCache.shared.cachedImage(for: url) {
            return .success(Image(uiImage: image))
        }
        return loadedURL == url ? phase : .empty
    }
}
