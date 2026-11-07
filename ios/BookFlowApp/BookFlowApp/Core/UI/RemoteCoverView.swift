import SwiftUI

struct RemoteCoverView: View {
    let url: URL?
    var width: CGFloat = 64
    var height: CGFloat = 96
    @Environment(\.displayScale) private var displayScale

    var body: some View {
        CoverImageContent(url: url, pixels: Int(max(width, height) * displayScale))
            .equatable()
            .frame(width: width, height: height)
            .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

struct CoverImageContent: View, Equatable {
    let url: URL?
    let pixels: Int
    @Environment(\.displayScale) private var displayScale
    @State private var bitmap: CoverBitmap?
    @State private var loadedURL: URL?

    static func == (lhs: Self, rhs: Self) -> Bool { lhs.url == rhs.url && lhs.pixels == rhs.pixels }

    var body: some View {
        let current = loadedURL == url ? bitmap : nil
        let cached = current == nil ? url.flatMap { CoverImagePipeline.shared.cachedImage(for: $0, maxPixelSize: pixels) } : nil
        Color.clear.overlay {
            if let bitmap = current ?? cached {
                Image(decorative: bitmap.image, scale: displayScale)
                    .resizable()
                    .scaledToFill()
            } else {
                placeholder
            }
        }
        .task(id: CoverRequest(url: url, pixels: pixels)) {
            guard let url else { bitmap = nil; loadedURL = nil; return }
            let image = await CoverImagePipeline.shared.image(for: url, maxPixelSize: pixels)
            guard !Task.isCancelled else { return }
            bitmap = image
            loadedURL = url
        }
    }

    private var placeholder: some View {
        RoundedRectangle(cornerRadius: 10)
            .fill(Color.secondary.opacity(0.15))
            .overlay(
                Image(systemName: "book.closed")
                    .foregroundStyle(.secondary)
            )
    }
}

extension RemoteCoverView {
    func coverShadow(opacity: Double = 0.08, radius: CGFloat = 10, y: CGFloat = 4) -> some View {
        background {
            // Shadow a fixed shape instead of inspecting every pixel of the cover.
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.white)
                .shadow(color: .black.opacity(opacity), radius: radius, y: y)
        }
    }
}

private struct CoverRequest: Equatable {
    let url: URL?
    let pixels: Int
}
