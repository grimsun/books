import SwiftUI

struct LibraryView: View {
    let environment: AppEnvironment

    @State private var selectedShelf: Shelf?
    @State private var items: [LibraryItem] = []

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

    private var filteredTitle: String {
        selectedShelf?.title ?? "All books"
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Menu {
                    Button("All") {
                        selectedShelf = nil
                    }

                    ForEach(Shelf.allCases) { shelf in
                        Button(shelf.title) {
                            selectedShelf = shelf
                        }
                    }
                } label: {
                    HStack(spacing: 8) {
                        Text(filteredTitle)
                        Image(systemName: "chevron.down")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(
                        Capsule(style: .continuous)
                            .fill(Color.white.opacity(0.72))
                    )
                    .overlay(
                        Capsule(style: .continuous)
                            .strokeBorder(Color.white.opacity(0.8), lineWidth: 1)
                    )
                }

                if items.isEmpty {
                    ContentUnavailableView(
                        "No Books Yet",
                        systemImage: "books.vertical",
                        description: Text("Saved books will show up here.")
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
        .task {
            await loadItems()
        }
        .onChange(of: selectedShelf) { _, _ in
            Task { await loadItems() }
        }
    }

    @MainActor
    private func loadItems() async {
        items = (try? await environment.libraryRepository.fetchLibrary(shelf: selectedShelf)) ?? []
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
                        Text("Page \(progress.progressValue)")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(.primary)

                        GeometryReader { geometry in
                            let fill = max(0.12, min(CGFloat(progress.progressValue) / 400, 1))

                            Capsule(style: .continuous)
                                .fill(Color.black.opacity(0.08))
                                .overlay(alignment: .leading) {
                                    Capsule(style: .continuous)
                                        .fill(Color(red: 0.22, green: 0.45, blue: 0.29))
                                        .frame(width: geometry.size.width * fill)
                                }
                        }
                        .frame(height: 8)
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
