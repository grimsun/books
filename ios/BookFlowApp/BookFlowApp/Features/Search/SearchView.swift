import SwiftUI

struct SearchView: View {
    let environment: AppEnvironment

    @State private var query = ""
    @State private var results: [Book] = []

    private let pageBackground = LinearGradient(
        colors: [
            Color(red: 0.99, green: 0.97, blue: 0.94),
            Color(red: 0.94, green: 0.96, blue: 0.92),
            Color(red: 0.95, green: 0.95, blue: 0.90)
        ],
        startPoint: .top,
        endPoint: .bottom
    )

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if results.isEmpty {
                    ContentUnavailableView(
                        query.isEmpty ? "Start Searching" : "No Results",
                        systemImage: "books.vertical",
                        description: Text(query.isEmpty ? "Search Open Library by title, author, or genre." : "Try a broader title or author search.")
                    )
                    .frame(maxWidth: .infinity)
                    .padding(.top, 56)
                } else {
                    LazyVStack(spacing: 14) {
                        ForEach(results) { book in
                            NavigationLink {
                                BookDetailView(environment: environment, bookID: book.id, recommendationReason: nil)
                            } label: {
                                SearchResultCard(book: book)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.top, 12)
            .padding(.bottom, 28)
        }
        .background(pageBackground.ignoresSafeArea())
        .navigationTitle("Search")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $query, prompt: "Title, author, genre")
        .textInputAutocapitalization(.words)
        .autocorrectionDisabled()
        .scrollDismissesKeyboard(.immediately)
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

private struct SearchResultCard: View {
    let book: Book

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            RemoteCoverView(url: book.coverURL, width: 94, height: 136)
                .shadow(color: .black.opacity(0.08), radius: 10, y: 4)

            VStack(alignment: .leading, spacing: 7) {
                Text(book.title)
                    .font(.system(size: 20, weight: .semibold, design: .rounded))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)

                Text(book.authors.map(\.name).joined(separator: ", "))
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)

                if !book.genres.isEmpty {
                    Text(book.genres.prefix(2).map(\.name).joined(separator: " • "))
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(.tertiary)
                }

                Spacer(minLength: 0)
            }

            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.white.opacity(0.7))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(Color.white.opacity(0.75), lineWidth: 1)
        )
    }
}
