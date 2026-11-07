import SwiftUI

struct SearchView: View {
    let environment: AppEnvironment

    @State private var query = ""
    @State private var search = BookSearchModel()
    @State private var retryCount = 0

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
        List {
            Group {
                if search.isLoading && search.results.isEmpty {
                    ProgressView("Searching books...")
                        .frame(maxWidth: .infinity)
                        .padding(.top, 56)
                } else if let error = search.errorMessage {
                    ContentUnavailableView {
                        Label("Couldn't Search", systemImage: "wifi.exclamationmark")
                    } description: {
                        Text(error)
                    } actions: {
                        Button("Try Again") { retryCount += 1 }
                            .buttonStyle(.bordered)
                    }
                } else if search.results.isEmpty {
                    ContentUnavailableView(
                        query.isEmpty ? "Start Searching" : "No Results",
                        systemImage: "books.vertical",
                        description: Text(query.isEmpty ? "Search Open Library by title, author, or genre." : "Try a broader title or author search.")
                    )
                    .frame(maxWidth: .infinity)
                    .padding(.top, 56)
                } else {
                    ForEach(search.results) { book in
                        NavigationLink {
                            BookDetailView(environment: environment, bookID: book.id, recommendationReason: nil, initialBook: book)
                        } label: {
                            SearchResultCard(book: book)
                        }
                        .buttonStyle(.plain)
                        .navigationLinkIndicatorVisibility(.hidden)
                        .accessibilityIdentifier("search-book-\(book.id)")
                    }
                }
            }
            .listRowInsets(EdgeInsets(top: 0, leading: 14, bottom: 14, trailing: 14))
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
        }
        .listStyle(.plain)
        .listRowSpacing(0)
        .environment(\.defaultMinListRowHeight, 0)
        .scrollContentBackground(.hidden)
        .contentMargins(.horizontal, 0, for: .scrollContent)
        .contentMargins(.top, 12, for: .scrollContent)
        .contentMargins(.bottom, 14, for: .scrollContent)
        .background(pageBackground.ignoresSafeArea())
        .overlay(alignment: .topTrailing) {
            if search.isLoading && !search.results.isEmpty {
                ProgressView()
                    .padding(16)
                    .allowsHitTesting(false)
            }
        }
        .navigationTitle("Search")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $query, prompt: "Title, author, genre")
        .textInputAutocapitalization(.words)
        .autocorrectionDisabled()
        .scrollDismissesKeyboard(.immediately)
        .task(id: SearchRequest(query: query, retryCount: retryCount)) {
            await search.search(query: query, using: environment.booksRepository)
        }
    }
}

private struct SearchRequest: Equatable {
    let query: String
    let retryCount: Int
}

private struct SearchResultCard: View {
    let book: Book

    var body: some View {
        BookSummaryCard(book: book) {
            EmptyView()
        } footer: {
            if !book.genres.isEmpty {
                Text(book.genres.prefix(2).map(\.name).joined(separator: " • "))
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }
        }
    }
}
