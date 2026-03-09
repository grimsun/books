import SwiftUI

struct LibraryView: View {
    let environment: AppEnvironment

    @State private var selectedShelf: Shelf?
    @State private var items: [LibraryItem] = []

    init(environment: AppEnvironment, initialShelf: Shelf? = nil) {
        self.environment = environment
        _selectedShelf = State(initialValue: initialShelf)
    }

    var body: some View {
        List {
            Section {
                Picker("Shelf", selection: $selectedShelf) {
                    Text("All").tag(Shelf?.none)
                    ForEach(Shelf.allCases) { shelf in
                        Text(shelf.title).tag(Optional(shelf))
                    }
                }
                .pickerStyle(.menu)
            }

            ForEach(items) { item in
                NavigationLink {
                    BookDetailView(environment: environment, bookID: item.book.id, recommendationReason: nil)
                } label: {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 12) {
                            RemoteCoverView(url: item.book.coverURL)

                            VStack(alignment: .leading, spacing: 4) {
                                Text(item.book.title)
                                    .font(.headline)
                                Text(item.shelf.title)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        if let progress = item.progress {
                            Text("Progress: \(progress.progressValue) \(progress.progressUnit.rawValue)")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .navigationTitle("Library")
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
