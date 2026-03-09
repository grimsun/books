import SwiftUI

struct HomeView: View {
    let environment: AppEnvironment

    @State private var recommendations: [RecommendationItem] = []
    @State private var wantToRead: [LibraryItem] = []
    @State private var currentlyReading: [LibraryItem] = []
    @State private var selectedFilter = "All"

    private let filters = ["All", "Recommended", "Want to Read", "Reading"]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header

                FilterRail(filters: filters, selectedFilter: $selectedFilter)

                if selectedFilter == "All" || selectedFilter == "Recommended" {
                    HomeRailSection(
                        title: "Recommended for now",
                        subtitle: "Based on the books you keep around longest.",
                        content: {
                            ForEach(recommendations) { item in
                                NavigationLink {
                                    BookDetailView(environment: environment, bookID: item.book.id, recommendationReason: item.reason)
                                } label: {
                                    RecommendationCard(item: item)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    )
                }

                if selectedFilter == "All" || selectedFilter == "Want to Read" {
                    HomeRailSection(
                        title: "Want to read",
                        subtitle: "Saved for the right mood.",
                        content: {
                            ForEach(wantToRead) { item in
                                NavigationLink {
                                    BookDetailView(environment: environment, bookID: item.book.id, recommendationReason: nil)
                                } label: {
                                    LibraryCard(item: item)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    )
                }

                if selectedFilter == "All" || selectedFilter == "Reading" {
                    HomeRailSection(
                        title: "Currently reading",
                        subtitle: "Pick up where you left off.",
                        content: {
                            ForEach(currentlyReading) { item in
                                NavigationLink {
                                    BookDetailView(environment: environment, bookID: item.book.id, recommendationReason: nil)
                                } label: {
                                    LibraryCard(item: item)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    )
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 12)
            .padding(.bottom, 24)
        }
        .background(
            LinearGradient(
                colors: [
                    Color(red: 0.99, green: 0.97, blue: 0.94),
                    Color(red: 0.94, green: 0.96, blue: 0.92),
                    Color(red: 0.95, green: 0.95, blue: 0.90)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        )
        .navigationBarTitleDisplayMode(.inline)
        .task {
            if recommendations.isEmpty {
                recommendations = (try? await environment.recommendationsRepository.fetchRecommendations()) ?? []
            }
            if wantToRead.isEmpty && currentlyReading.isEmpty {
                wantToRead = (try? await environment.libraryRepository.fetchLibrary(shelf: .wantToRead)) ?? []
                currentlyReading = (try? await environment.libraryRepository.fetchLibrary(shelf: .reading)) ?? []
            }
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Bookflow")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Color(red: 0.22, green: 0.45, blue: 0.29))
                Text("Sunday reading")
                    .font(.system(size: 22, weight: .semibold, design: .rounded))
            }

            Spacer()

            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.75))
                    .frame(width: 42, height: 42)

                Image(systemName: "books.vertical.fill")
                    .foregroundStyle(Color(red: 0.22, green: 0.45, blue: 0.29))
            }
            .overlay(
                Circle()
                    .stroke(Color.white.opacity(0.6), lineWidth: 1)
            )
        }
    }
}

private struct HomeRailSection<Content: View>: View {
    let title: String
    let subtitle: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                Text(subtitle)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 6) {
                    content()
                }
                .padding(.horizontal, 1)
            }
        }
    }
}

private struct FilterRail: View {
    let filters: [String]
    @Binding var selectedFilter: String

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(filters, id: \.self) { filter in
                    Button(filter) {
                        selectedFilter = filter
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(selectedFilter == filter ? Color.white : Color.primary)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 11)
                    .background(
                        Capsule()
                            .fill(selectedFilter == filter ? Color(red: 0.22, green: 0.45, blue: 0.29) : Color.white.opacity(0.72))
                    )
                    .overlay(
                        Capsule()
                            .stroke(Color.white.opacity(0.65), lineWidth: 1)
                    )
                }
            }
            .padding(.horizontal, 1)
        }
    }
}

private struct RecommendationCard: View {
    let item: RecommendationItem

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            RemoteCoverView(url: item.book.coverURL, width: 136, height: 194)
            VStack(alignment: .leading, spacing: 7) {
                Text(item.book.title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                Text(item.book.authors.map(\.name).joined(separator: ", "))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                CardTagRow(tag: recommendationTag)
            }
        }
        .frame(width: 140, alignment: .leading)
    }

    private var recommendationTag: String {
        item.book.genres.first?.name ?? item.reasonTag ?? "Recommended"
    }
}

private struct LibraryCard: View {
    let item: LibraryItem

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            ZStack(alignment: .bottomLeading) {
                RemoteCoverView(url: item.book.coverURL, width: 136, height: 194)

                if let progress = item.progress {
                    Text(progressLabel(progress))
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                        .background(Color.black.opacity(0.72), in: Capsule())
                        .padding(10)
                }
            }

            VStack(alignment: .leading, spacing: 7) {
                Text(item.book.title)
                    .font(.headline)
                    .lineLimit(2)
                Text(item.book.authors.map(\.name).joined(separator: ", "))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                CardTagRow(tag: libraryTag)
            }
        }
        .frame(width: 140, alignment: .leading)
    }

    private func progressLabel(_ progress: ReadingProgress) -> String {
        switch progress.progressUnit {
        case .page:
            return "Page \(progress.progressValue)"
        case .percent:
            return "\(progress.progressValue)%"
        }
    }

    private var libraryTag: String {
        item.book.genres.first?.name ?? item.shelf.title
    }
}

private struct CardTagRow: View {
    let tag: String

    var body: some View {
        Text(tag)
            .font(.caption2.weight(.medium))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(Color.white.opacity(0.72), in: Capsule())
    }
}

private extension RecommendationItem {
    var reasonTag: String? {
        let normalized = reason.lowercased()

        if normalized.contains("fantasy") {
            return "Fantasy"
        }
        if normalized.contains("literary") {
            return "Literary"
        }
        if normalized.contains("completion") {
            return "High Finish Rate"
        }
        if normalized.contains("immersive") {
            return "Immersive"
        }
        if normalized.contains("similar") {
            return "Because You Read"
        }

        return nil
    }
}
