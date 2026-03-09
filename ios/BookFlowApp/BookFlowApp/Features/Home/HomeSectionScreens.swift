import SwiftUI

struct RecommendationListView: View {
    let environment: AppEnvironment
    let title: String
    let subtitle: String
    let items: [RecommendationItem]

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text(title)
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 8)
            }

            ForEach(items) { item in
                NavigationLink {
                    BookDetailView(environment: environment, bookID: item.book.id, recommendationReason: item.reason)
                } label: {
                    ListBookRow(book: item.book)
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct PopularGridView: View {
    let environment: AppEnvironment
    let tiles: [PopularBookTile]

    private let columns = [
        GridItem(.flexible(), spacing: 4),
        GridItem(.flexible(), spacing: 4),
        GridItem(.flexible(), spacing: 4),
        GridItem(.flexible(), spacing: 4)
    ]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 4) {
                ForEach(tiles) { tile in
                    NavigationLink {
                        BookDetailView(environment: environment, bookID: tile.bookID, recommendationReason: nil)
                    } label: {
                        Image(tile.assetName)
                            .resizable()
                            .scaledToFill()
                            .aspectRatio(0.68, contentMode: .fit)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(14)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Popular")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct ListBookRow: View {
    let book: Book

    var body: some View {
        HStack(spacing: 12) {
            RemoteCoverView(url: book.coverURL, width: 56, height: 82)

            VStack(alignment: .leading, spacing: 4) {
                Text(book.title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                Text(book.authors.map(\.name).joined(separator: ", "))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Text(book.genres.map(\.name).joined(separator: " • "))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 4)
    }
}
