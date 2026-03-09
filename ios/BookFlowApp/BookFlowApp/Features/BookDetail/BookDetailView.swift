import SwiftUI

struct BookDetailView: View {
    let environment: AppEnvironment
    let bookID: String
    let recommendationReason: String?

    @State private var book: Book?
    @State private var selectedShelf: Shelf = .wantToRead
    @State private var progressValue = ""

    var body: some View {
        ScrollView {
            if let book {
                VStack(alignment: .leading, spacing: 20) {
                    HStack(alignment: .top, spacing: 16) {
                        RemoteCoverView(url: book.coverURL)
                            .frame(width: 96, height: 144)

                        VStack(alignment: .leading, spacing: 8) {
                            Text(book.title)
                                .font(.title2.bold())
                            Text(book.authors.map(\.name).joined(separator: ", "))
                                .foregroundStyle(.secondary)
                            Text(book.genres.map(\.name).joined(separator: " • "))
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }

                    if let recommendationReason {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Why this")
                                .font(.headline)
                            Text(recommendationReason)
                                .foregroundStyle(.secondary)
                        }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Add to shelf")
                            .font(.headline)
                        Picker("Shelf", selection: $selectedShelf) {
                            ForEach(Shelf.allCases) { shelf in
                                Text(shelf.title).tag(shelf)
                            }
                        }
                        .pickerStyle(.segmented)

                        Button("Save to Library") {
                            Task {
                                try? await environment.libraryRepository.upsertLibraryItem(
                                    bookID: book.id,
                                    shelf: selectedShelf,
                                    owned: false
                                )
                            }
                        }
                        .buttonStyle(.borderedProminent)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Progress")
                            .font(.headline)
                        TextField("Current page", text: $progressValue)
                            .keyboardType(.numberPad)
                            .textFieldStyle(.roundedBorder)
                        Button("Update Progress") {
                            Task {
                                let progress = ReadingProgress(progressUnit: .page, progressValue: Int(progressValue) ?? 0)
                                try? await environment.libraryRepository.updateProgress(bookID: book.id, progress: progress)
                            }
                        }
                        .buttonStyle(.bordered)
                    }

                    if let description = book.description {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("About")
                                .font(.headline)
                            Text(description)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding()
            }
        }
        .navigationTitle("Book")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            if book == nil {
                book = try? await environment.booksRepository.fetchBook(id: bookID)
            }
        }
    }
}
