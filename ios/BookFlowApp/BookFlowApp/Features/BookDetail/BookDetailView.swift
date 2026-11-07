import SwiftUI

struct BookDetailView: View {
    let environment: AppEnvironment
    let bookID: String
    let recommendationReason: String?

    @State private var book: Book?
    @State private var selectedShelf: Shelf = .wantToRead
    @State private var progressValue = ""
    @State private var progressUnit: ProgressUnit = .page
    @State private var isLoading = true
    @State private var isSaving = false
    @State private var isSaved = false
    @State private var owned = false
    @State private var errorMessage: String?
    @State private var statusMessage: String?
    @State private var retryCount = 0

    init(environment: AppEnvironment, bookID: String, recommendationReason: String?, initialBook: Book? = nil) {
        self.environment = environment
        self.bookID = bookID
        self.recommendationReason = recommendationReason
        _book = State(initialValue: initialBook ?? MockSeedData.booksByID[bookID])
    }

    var body: some View {
        ScrollView {
            if let book {
                VStack(alignment: .leading, spacing: 20) {
                    HStack(alignment: .top, spacing: 16) {
                        RemoteCoverView(url: book.coverURL, width: 112, height: 168)

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

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Shelf")
                            .font(.headline)
                        Picker("Shelf", selection: $selectedShelf) {
                            ForEach(Shelf.allCases) { shelf in
                                Text(shelf.title).tag(shelf)
                            }
                        }
                        .pickerStyle(.menu)

                        Button(isSaving ? "Saving..." : "Save to Library") {
                            Task { await saveBook(book) }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(isSaving)
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Progress")
                            .font(.headline)
                        Picker("Progress unit", selection: $progressUnit) {
                            Text("Pages").tag(ProgressUnit.page)
                            Text("Percent").tag(ProgressUnit.percent)
                        }
                        .pickerStyle(.segmented)

                        TextField(progressUnit == .page ? "Current page" : "Percent complete", text: $progressValue)
                            .keyboardType(.numberPad)
                            .textFieldStyle(.roundedBorder)
                            .accessibilityIdentifier("readingProgress")
                        Button("Update Progress") {
                            Task { await updateProgress(book) }
                        }
                        .buttonStyle(.bordered)
                        .disabled(!isSaved || isSaving || Int(progressValue) == nil)

                        if !isSaved {
                            Text("Save to your library to track progress.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }

                    if let statusMessage {
                        Label(statusMessage, systemImage: "checkmark.circle.fill")
                            .font(.subheadline)
                            .foregroundStyle(.green)
                            .accessibilityIdentifier("bookSaveStatus")
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
                .padding(14)
            } else if isLoading {
                ProgressView("Loading book...")
                    .padding(.top, 56)
            } else {
                ContentUnavailableView {
                    Label("Couldn't Load Book", systemImage: "book.closed")
                } description: {
                    Text(errorMessage ?? "Please try again.")
                } actions: {
                    Button("Try Again") { retryCount += 1 }
                }
            }
        }
        .navigationTitle("Book")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: "\(bookID)-\(retryCount)") { await loadBook() }
        .alert("Couldn't Save", isPresented: Binding(
            get: { book != nil && errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "Please try again.")
        }
    }

    @MainActor
    private func loadBook() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let items = try await environment.libraryRepository.fetchLibrary(shelf: nil)
            if let existing = items.first(where: { $0.book.id == bookID }) {
                book = existing.book
                selectedShelf = existing.shelf
                owned = existing.owned
                isSaved = true
                progressUnit = existing.progress?.progressUnit ?? .page
                progressValue = existing.progress.map { String($0.progressValue) } ?? ""
            } else {
                book = try await environment.booksRepository.fetchBook(id: bookID)
            }
        } catch {
            if !Task.isCancelled { errorMessage = error.localizedDescription }
        }
    }

    @MainActor
    private func saveBook(_ book: Book) async {
        isSaving = true
        statusMessage = nil
        defer { isSaving = false }
        do {
            try await environment.libraryRepository.upsertLibraryItem(bookID: book.id, shelf: selectedShelf, owned: owned)
            isSaved = true
            environment.libraryRevision += 1
            statusMessage = "Saved to \(selectedShelf.title)"
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func updateProgress(_ book: Book) async {
        guard let value = Int(progressValue) else { return }
        isSaving = true
        statusMessage = nil
        defer { isSaving = false }
        do {
            let progress = ReadingProgress(progressUnit: progressUnit, progressValue: value)
            try await environment.libraryRepository.updateProgress(bookID: book.id, progress: progress)
            environment.libraryRevision += 1
            statusMessage = "Progress updated"
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
