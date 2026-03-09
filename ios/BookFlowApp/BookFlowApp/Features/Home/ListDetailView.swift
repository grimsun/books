import SwiftUI

struct ListDetailView: View {
    let environment: AppEnvironment
    let list: CuratedBookList

    private var books: [Book] {
        list.bookIDs.compactMap { id in
            MockSeedData.books.first(where: { $0.id == id })
        }
    }

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 10) {
                    Text(list.title)
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                    Text(list.subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 8)
            }

            ForEach(books) { book in
                NavigationLink {
                    BookDetailView(environment: environment, bookID: book.id, recommendationReason: nil)
                } label: {
                    ListBookRow(book: book)
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("List")
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
