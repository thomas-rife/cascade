import SwiftUI
import UIKit

/// Artwork survives lazy-grid view recycling, with disk backing for memory evictions.
@MainActor
final class ArtworkCache {
    static let shared = ArtworkCache()

    private let images = NSCache<NSURL, UIImage>()
    private let responses = URLCache(
        memoryCapacity: 16 * 1024 * 1024,
        diskCapacity: 512 * 1024 * 1024,
        diskPath: "artwork"
    )
    private let session: URLSession
    private var downloads: [URL: Task<UIImage, Error>] = [:]

    private init() {
        images.totalCostLimit = 128 * 1024 * 1024
        let configuration = URLSessionConfiguration.default
        configuration.urlCache = responses
        configuration.requestCachePolicy = .returnCacheDataElseLoad
        session = URLSession(configuration: configuration)
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
            let request = URLRequest(url: url, cachePolicy: .returnCacheDataElseLoad)
            let data: Data
            let response: URLResponse
            if let cached = responses.cachedResponse(for: request) {
                data = cached.data
                response = cached.response
            } else {
                (data, response) = try await session.data(for: request)
            }
            guard let http = response as? HTTPURLResponse,
                  (200..<300).contains(http.statusCode),
                  let image = UIImage(data: data) else {
                responses.removeCachedResponse(for: request)
                throw URLError(.cannotDecodeContentData)
            }

            // Jellyfin image URLs include the image tag, so changed artwork gets a new key.
            responses.storeCachedResponse(
                CachedURLResponse(response: response, data: data), for: request
            )
            let cost = image.cgImage.map { $0.bytesPerRow * $0.height } ?? data.count
            images.setObject(image, forKey: url as NSURL, cost: cost)
            return image
        }
        downloads[url] = download
        return try await download.value
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
