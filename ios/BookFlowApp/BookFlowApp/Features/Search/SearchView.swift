import SwiftUI

struct SearchView: View {
    let environment: AppEnvironment

    @State private var query = ""
    @State private var results: [Book] = []

    var body: some View {
        List {
            if results.isEmpty {
                ContentUnavailableView(
                    query.isEmpty ? "Start Searching" : "No Results",
                    systemImage: "books.vertical",
                    description: Text(query.isEmpty ? "Search Open Library by title, author, or genre." : "Try a broader title or author search.")
                )
                .listRowBackground(Color.clear)
            } else {
                ForEach(results) { book in
                    NavigationLink {
                        BookDetailView(environment: environment, bookID: book.id, recommendationReason: nil)
                    } label: {
                        BookRow(book: book)
                    }
                }
            }
        }
        .navigationTitle("Search")
        .searchable(text: $query, prompt: "Title, author, genre")
        .task {
            if results.isEmpty {
                results = (try? await environment.booksRepository.searchBooks(query: "")) ?? []
            }
        }
        .onChange(of: query) { _, newValue in
            Task {
                results = (try? await environment.booksRepository.searchBooks(query: newValue)) ?? []
            }
        }
    }
}

private struct BookRow: View {
    let book: Book

    var body: some View {
        HStack(spacing: 12) {
            RemoteCoverView(url: book.coverURL)

            VStack(alignment: .leading, spacing: 4) {
                Text(book.title)
                    .font(.headline)
                Text(book.authors.map(\.name).joined(separator: ", "))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(book.genres.map(\.name).joined(separator: " • "))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}
