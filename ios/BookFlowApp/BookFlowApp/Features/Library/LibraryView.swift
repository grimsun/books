import SwiftUI

struct LibraryView: View {
    let environment: AppEnvironment

    @State private var selectedShelf: Shelf?
    @State private var items: [LibraryItem] = []
    @State private var isLoading = true
    @State private var errorMessage: String?

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

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
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
                } else if items.isEmpty {
                    ContentUnavailableView(
                        selectedShelf == nil ? "No Books Yet" : "No \(selectedShelf?.title ?? "Books") Yet",
                        systemImage: "books.vertical",
                        description: Text(selectedShelf == nil ? "Saved books will show up here." : "Books on this shelf will show up here.")
                    )
                    .frame(maxWidth: .infinity)
                    .padding(.top, 48)
                } else {
                    LazyVStack(spacing: 14) {
                        ForEach(items) { item in
                            NavigationLink {
                                BookDetailView(environment: environment, bookID: item.book.id, recommendationReason: nil)
                            } label: {
                                LibraryItemCard(item: item)
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("library-book-\(item.book.id)")
                        }
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.top, 12)
            .padding(.bottom, 28)
        }
        .background(pageBackground.ignoresSafeArea())
        .navigationTitle("Library")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: "\(selectedShelf?.rawValue ?? "all")-\(environment.libraryRevision)") {
            await loadItems()
        }
    }

    @MainActor
    private func loadItems() async {
        let shelf = selectedShelf
        isLoading = true
        errorMessage = nil
        defer { if !Task.isCancelled { isLoading = false } }
        do {
            let loaded = try await environment.libraryRepository.fetchLibrary(shelf: shelf)
            try Task.checkCancellation()
            items = loaded
        } catch {
            if !Task.isCancelled { errorMessage = error.localizedDescription }
        }
    }

    private func shelfChip(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(title, action: action)
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
        HStack(alignment: .top, spacing: 14) {
            RemoteCoverView(url: item.book.coverURL, width: 98, height: 144)
                .shadow(color: .black.opacity(0.08), radius: 10, y: 4)

            VStack(alignment: .leading, spacing: 8) {
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

                Text(item.book.title)
                    .font(.system(size: 20, weight: .semibold, design: .rounded))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)

                Text(item.book.authors.map(\.name).joined(separator: ", "))
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)

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
