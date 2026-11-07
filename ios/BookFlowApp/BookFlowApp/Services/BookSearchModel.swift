import Foundation
import Observation

@Observable
@MainActor
final class BookSearchModel {
    private(set) var results: [Book] = []
    private(set) var isLoading = false
    private(set) var errorMessage: String?
    private var requestID = 0

    func search(query: String, using repository: any BooksRepository, debounce: Duration = .milliseconds(400)) async {
        requestID += 1
        let currentID = requestID
        isLoading = true
        errorMessage = nil
        results = []
        defer { if currentID == requestID { isLoading = false } }
        do {
            if !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                try await Task.sleep(for: debounce)
            }
            try Task.checkCancellation()
            let books = try await repository.searchBooks(query: query)
            try Task.checkCancellation()
            guard currentID == requestID else { return }
            results = books
        } catch {
            guard currentID == requestID, !Task.isCancelled else { return }
            errorMessage = error.localizedDescription
        }
    }
}
