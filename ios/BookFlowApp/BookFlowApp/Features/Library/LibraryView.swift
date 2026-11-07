import SwiftUI

struct LibraryView: View {
    let environment: AppEnvironment

    @State private var selectedShelf: Shelf?
    @State private var items: [LibraryItem] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var loadedRevision: Int?

    private let pageBackground = LinearGradient(
        colors: [
            Color(red: 0.99, green: 0.97, blue: 0.94),
            Color(red: 0.94, green: 0.96, blue: 0.92),
            Color(red: 0.95, green: 0.95, blue: 0.90)
        ],
        startPoint: .top,
        endPoint: .bottom
    )

    init(environment: AppEnvironment, initialShelf: Shelf? = nil) {
        self.environment = environment
        _selectedShelf = State(initialValue: initialShelf)
    }

    private var visibleItems: [LibraryItem] {
        guard let selectedShelf else { return items }
        return items.filter { $0.shelf == selectedShelf }
    }

    var body: some View {
        List {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    shelfChip(title: "All books", isSelected: selectedShelf == nil) {
                        selectedShelf = nil
                    }

                    ForEach(Shelf.allCases) { shelf in
                        shelfChip(title: shelf.title, isSelected: selectedShelf == shelf) {
                            selectedShelf = shelf
                        }
                    }
                }
                .padding(.horizontal, 1)
            }
            .listRowInsets(EdgeInsets(top: 0, leading: 14, bottom: 18, trailing: 14))
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)

            Group {
                if isLoading {
                    ProgressView("Loading library...")
                        .frame(maxWidth: .infinity)
                        .padding(.top, 48)
                } else if let errorMessage {
                    ContentUnavailableView {
                        Label("Couldn't Load Library", systemImage: "exclamationmark.triangle")
                    } description: {
                        Text(errorMessage)
                    } actions: {
                        Button("Try Again") { Task { await loadItems() } }
                    }
                } else if visibleItems.isEmpty {
                    ContentUnavailableView(
                        selectedShelf == nil ? "No Books Yet" : "No \(selectedShelf?.title ?? "Books") Yet",
                        systemImage: "books.vertical",
                        description: Text(selectedShelf == nil ? "Saved books will show up here." : "Books on this shelf will show up here.")
                    )
                    .frame(maxWidth: .infinity)
                    .padding(.top, 48)
                } else {
                    ForEach(visibleItems) { item in
                        NavigationLink {
                            BookDetailView(environment: environment, bookID: item.book.id, recommendationReason: nil, initialBook: item.book)
                        } label: {
                            LibraryItemCard(item: item)
                        }
                        .buttonStyle(.plain)
                        .navigationLinkIndicatorVisibility(.hidden)
                        .accessibilityIdentifier("library-book-\(item.book.id)")
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
        .accessibilityIdentifier("library-scroll")
        .accessibilityValue(selectedShelf?.rawValue ?? "all")
        .navigationTitle("Library")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: environment.libraryRevision) {
            guard loadedRevision != environment.libraryRevision else { return }
            await loadItems()
        }
    }

    @MainActor
    private func loadItems() async {
        let revision = environment.libraryRevision
        isLoading = items.isEmpty
        errorMessage = nil
        defer { if !Task.isCancelled { isLoading = false } }
        do {
            let loaded = try await environment.libraryRepository.fetchLibrary(shelf: nil)
            try Task.checkCancellation()
            if items != loaded { items = loaded }
            loadedRevision = revision
        } catch {
            if !Task.isCancelled { errorMessage = error.localizedDescription }
        }
    }

    private func shelfChip(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(title, action: action)
            .accessibilityIdentifier("library-shelf-\(title == "All books" ? "all" : Shelf.allCases.first(where: { $0.title == title })?.rawValue ?? title)")
            .accessibilityValue(isSelected ? "Selected" : "Not selected")
            .buttonStyle(.plain)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(isSelected ? Color.white : Color.primary)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                Capsule()
                    .fill(
                        isSelected
                        ? Color(red: 0.22, green: 0.45, blue: 0.29)
                        : Color.white.opacity(0.72)
                    )
            )
            .overlay(
                Capsule()
                    .stroke(Color.white.opacity(0.65), lineWidth: 1)
            )
    }
}

private struct LibraryItemCard: View {
    let item: LibraryItem

    var body: some View {
        BookSummaryCard(book: item.book, coverWidth: 98, coverHeight: 144, textSpacing: 8) {
            HStack {
                Text(item.shelf.title)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color(red: 0.22, green: 0.45, blue: 0.29))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color(red: 0.84, green: 0.91, blue: 0.82).opacity(0.9))
                    .clipShape(Capsule())

                Spacer(minLength: 0)
            }
        } footer: {
            if let progress = item.progress {
                VStack(alignment: .leading, spacing: 6) {
                    Text(progress.label)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(.primary)

                    if let fraction = progress.fraction(pageCount: item.book.pageCount) {
                        ProgressView(value: fraction)
                            .tint(Color(red: 0.22, green: 0.45, blue: 0.29))
                    }
                }
            }
        }
    }
}
