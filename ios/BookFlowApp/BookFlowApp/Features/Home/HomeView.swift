import SwiftUI
import UIKit

struct HomeView: View {
    let environment: AppEnvironment

    @State private var recommendations: [RecommendationItem] = []
    @State private var currentlyReading: [LibraryItem] = []
    @State private var weeklyRhythm = MockSeedData.weeklyReadingStatus

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
        ZStack(alignment: .top) {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header

                    if environment.session.showWeeklyRhythm {
                        WeeklyRhythmStrip(days: $weeklyRhythm)
                    }

                    CurrentlyReadingSection(environment: environment, items: currentlyReading)

                    RecommendedSection(environment: environment, items: recommendations)

                    PopularSection(environment: environment, tiles: MockSeedData.popularTiles)

                    MoodSection(environment: environment, shelves: MockSeedData.moodShelves)

                    ListsSection(environment: environment, curatedLists: MockSeedData.curatedLists)
                }
                .padding(.horizontal, 14)
                .padding(.top, 12)
                .padding(.bottom, 24)
            }
        }
        .background(pageBackground.ignoresSafeArea())
        .overlay(alignment: .top) {
            TopBezelFade(background: pageBackground)
                .allowsHitTesting(false)
        }
        .navigationBarTitleDisplayMode(.inline)
        .task {
            if recommendations.isEmpty {
                recommendations = (try? await environment.recommendationsRepository.fetchRecommendations()) ?? []
            }
            if currentlyReading.isEmpty {
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

private struct TopBezelFade: View {
    let background: LinearGradient

    var body: some View {
        VStack(spacing: 0) {
            background
                .frame(height: 18)

            LinearGradient(
                colors: [
                    Color(red: 0.99, green: 0.97, blue: 0.94),
                    Color(red: 0.99, green: 0.97, blue: 0.94).opacity(0.94),
                    Color(red: 0.99, green: 0.97, blue: 0.94).opacity(0.0)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 54)
        }
        .ignoresSafeArea(edges: .top)
    }
}

private struct WeeklyRhythmStrip: View {
    @Binding var days: [ReadingDayStatus]

    var body: some View {
        HStack(spacing: 10) {
            ForEach(Array(days.enumerated()), id: \.element.id) { index, day in
                VStack(spacing: 8) {
                    ZStack {
                        Circle()
                            .fill(circleFill(for: day))
                            .frame(width: 34, height: 34)

                        if day.isCompleted {
                            Image(systemName: "checkmark")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(day.isToday ? Color.white : Color(red: 0.22, green: 0.45, blue: 0.29))
                        } else {
                            Text(day.label)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(day.isToday ? Color.white : Color.secondary)
                        }
                    }
                    .overlay(
                        Circle()
                            .stroke(circleStroke(for: day), lineWidth: day.isToday ? 1.5 : 1)
                    )

                    Text(day.label)
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
                .onLongPressGesture(minimumDuration: 0.4) {
                    days[index].isCompleted.toggle()
                    let generator = UIImpactFeedbackGenerator(style: .light)
                    generator.impactOccurred()
                }
            }
        }
        .padding(.vertical, 2)
    }

    private func circleFill(for day: ReadingDayStatus) -> Color {
        if day.isToday {
            return Color(red: 0.22, green: 0.45, blue: 0.29)
        }
        if day.isCompleted {
            return Color(red: 0.87, green: 0.93, blue: 0.85)
        }
        return Color.white.opacity(0.72)
    }

    private func circleStroke(for day: ReadingDayStatus) -> Color {
        if day.isToday {
            return Color.white.opacity(0.78)
        }
        return Color.white.opacity(0.6)
    }
}

private struct RecommendedSection: View {
    let environment: AppEnvironment
    let items: [RecommendationItem]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HomeSectionHeader(
                title: "Recommended for you",
                subtitle: "A few strong picks based on your recent reading."
            ) {
                RecommendationListView(
                    environment: environment,
                    title: "Recommended for you",
                    subtitle: "A few strong picks based on your recent reading.",
                    items: items
                )
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 6) {
                    ForEach(items) { item in
                        NavigationLink {
                            BookDetailView(environment: environment, bookID: item.book.id, recommendationReason: item.reason)
                        } label: {
                            RecommendationCard(item: item)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 1)
            }
        }
    }
}

private struct MoodSection: View {
    let environment: AppEnvironment
    let shelves: [MoodRecommendationShelf]

    @State private var selectedMoodID: String

    init(environment: AppEnvironment, shelves: [MoodRecommendationShelf]) {
        self.environment = environment
        self.shelves = shelves
        _selectedMoodID = State(initialValue: shelves.first?.id ?? "")
    }

    private var selectedShelf: MoodRecommendationShelf? {
        shelves.first(where: { $0.id == selectedMoodID }) ?? shelves.first
    }

    private var selectedBooks: [Book] {
        guard let selectedShelf else { return [] }
        return selectedShelf.recommendationBookIDs.compactMap { id in
            MockSeedData.books.first(where: { $0.id == id })
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HomeSectionHeader(
                title: "Pick a mood",
                subtitle: "Recommendations that match how you want to read right now."
            ) {
                RecommendationListView(
                    environment: environment,
                    title: selectedShelf?.title ?? "Pick a mood",
                    subtitle: "Recommendations that match how you want to read right now.",
                    items: selectedBooks.map {
                        RecommendationItem(book: $0, reason: selectedShelf?.title ?? "Mood pick", score: 0.0)
                    }
                )
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(shelves) { shelf in
                        Button(shelf.title) {
                            selectedMoodID = shelf.id
                        }
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(selectedMoodID == shelf.id ? Color.white : Color.primary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(
                            Capsule()
                                .fill(
                                    selectedMoodID == shelf.id
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
                .padding(.horizontal, 1)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 6) {
                    ForEach(selectedBooks) { book in
                        NavigationLink {
                            BookDetailView(environment: environment, bookID: book.id, recommendationReason: selectedShelf?.title)
                        } label: {
                            MoodBookCard(book: book, moodTitle: selectedShelf?.title ?? "For you")
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 1)
            }
        }
    }
}

private struct ListsSection: View {
    let environment: AppEnvironment
    let curatedLists: [CuratedBookList]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HomeSectionHeader(
                title: "Lists",
                subtitle: "Curated shelves built from multiple covers."
            ) {
                ListsIndexView(environment: environment, curatedLists: curatedLists)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 0) {
                    ForEach(curatedLists) { list in
                        NavigationLink {
                            ListDetailView(environment: environment, list: list)
                        } label: {
                            CuratedListCard(list: list)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 1)
            }
        }
    }
}

private struct CurrentlyReadingSection: View {
    let environment: AppEnvironment
    let items: [LibraryItem]
    @State private var selectedIndex = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                HomeSectionTitle(
                    title: "Currently reading",
                    subtitle: nil,
                    fontSize: 28
                )

                Spacer()

                HStack(spacing: 10) {
                    if items.count > 1 {
                        Text("\(selectedIndex + 1) / \(items.count)")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }

                    NavigationLink("See all") {
                        LibraryView(environment: environment, initialShelf: .reading)
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color(red: 0.22, green: 0.45, blue: 0.29))
                }
            }

            if items.count > 1 {
                TabView(selection: $selectedIndex) {
                    ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                        NavigationLink {
                            BookDetailView(environment: environment, bookID: item.book.id, recommendationReason: nil)
                        } label: {
                            FeaturedReadingCard(item: item)
                        }
                        .buttonStyle(.plain)
                        .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .frame(height: 236)
            } else if let item = items.first {
                NavigationLink {
                    BookDetailView(environment: environment, bookID: item.book.id, recommendationReason: nil)
                } label: {
                    FeaturedReadingCard(item: item)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

private struct PopularSection: View {
    let environment: AppEnvironment
    let tiles: [PopularBookTile]

    private let spacing: CGFloat = 4
    private let columnCount: CGFloat = 4

    var body: some View {
        GeometryReader { proxy in
            let itemWidth = floor((proxy.size.width - (spacing * (columnCount - 1))) / columnCount)
            let rowCount = ceil(CGFloat(tiles.count) / columnCount)
            let gridHeight = (rowCount * (itemWidth * 1.46)) + ((rowCount - 1) * spacing)

            VStack(alignment: .leading, spacing: 10) {
                HomeSectionHeader(
                    title: "Popular",
                    subtitle: "What readers are saving right now."
                ) {
                    PopularGridView(environment: environment, tiles: tiles)
                }

                LazyVGrid(
                    columns: Array(repeating: GridItem(.fixed(itemWidth), spacing: spacing), count: Int(columnCount)),
                    alignment: .leading,
                    spacing: spacing
                ) {
                    ForEach(tiles) { tile in
                        NavigationLink {
                            BookDetailView(environment: environment, bookID: tile.bookID, recommendationReason: nil)
                        } label: {
                            PopularThumbnail(assetName: tile.assetName, width: itemWidth)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: 56 + gridHeight, alignment: .top)
        }
        .frame(height: popularSectionHeight)
    }

    private var popularSectionHeight: CGFloat {
        let availableWidth = UIScreen.main.bounds.width - 28
        let itemWidth = floor((availableWidth - (spacing * (columnCount - 1))) / columnCount)
        let rowCount = ceil(CGFloat(tiles.count) / columnCount)
        let gridHeight = (rowCount * (itemWidth * 1.46)) + ((rowCount - 1) * spacing)
        return 56 + gridHeight
    }
}

private struct ListsIndexView: View {
    let environment: AppEnvironment
    let curatedLists: [CuratedBookList]

    var body: some View {
        List(curatedLists) { list in
            NavigationLink {
                ListDetailView(environment: environment, list: list)
            } label: {
                VStack(alignment: .leading, spacing: 4) {
                    Text(list.title)
                        .font(.headline)
                    Text(list.subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }
        }
        .navigationTitle("Lists")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct HomeSectionHeader<Destination: View>: View {
    let title: String
    let subtitle: String?
    @ViewBuilder let destination: () -> Destination

    var body: some View {
        HStack(alignment: .top) {
            HomeSectionTitle(title: title, subtitle: subtitle, fontSize: 24)
            Spacer()
            NavigationLink("See all") {
                destination()
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(Color(red: 0.22, green: 0.45, blue: 0.29))
        }
    }
}

private struct HomeSectionTitle: View {
    let title: String
    let subtitle: String?
    let fontSize: CGFloat

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: fontSize, weight: .bold, design: .rounded))
            if let subtitle {
                Text(subtitle)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct CuratedListCard: View {
    let list: CuratedBookList

    private var books: [Book] {
        list.bookIDs.compactMap { id in
            MockSeedData.books.first(where: { $0.id == id })
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            CuratedListMosaic(books: books)

            VStack(alignment: .leading, spacing: 4) {
                Text(list.title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                Text(list.subtitle)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .padding(.horizontal, 2)
        }
        .frame(width: 252, alignment: .leading)
    }
}

private struct CuratedListMosaic: View {
    let books: [Book]

    var body: some View {
        HStack(spacing: 6) {
            if let leading = books[safe: 0] {
                RemoteCoverView(url: leading.coverURL, width: 148, height: 206)
            }

            VStack(spacing: 6) {
                mosaicTile(for: books[safe: 1], width: 74, height: 100)

                ZStack(alignment: .bottomTrailing) {
                    mosaicTile(for: books[safe: 2], width: 74, height: 100)
                    if books.count > 3 {
                        countBadge(extraCount: books.count - 3)
                            .padding(8)
                    }
                }
            }
        }
        .padding(10)
        .background(Color.white.opacity(0.55), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    @ViewBuilder
    private func mosaicTile(for book: Book?, width: CGFloat, height: CGFloat) -> some View {
        if let book {
            RemoteCoverView(url: book.coverURL, width: width, height: height)
        } else {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.6))
                .frame(width: width, height: height)
        }
    }

    private func countBadge(extraCount: Int) -> some View {
        Text("+\(extraCount)")
            .font(.caption.weight(.bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(Color.black.opacity(0.72), in: Capsule())
    }
}

private struct PopularThumbnail: View {
    let assetName: String
    let width: CGFloat

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.white.opacity(0.55))

            Image(assetName)
                .resizable()
                .scaledToFill()
                .frame(width: width - 4, height: (width - 4) * 1.46)
                .clipped()
        }
        .frame(width: width, height: width * 1.46)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

private struct FeaturedReadingCard: View {
    let item: LibraryItem

    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 12) {
                Text(item.book.title)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.white)
                    .lineLimit(2)

                Text(item.book.authors.map(\.name).joined(separator: ", "))
                    .font(.subheadline)
                    .foregroundStyle(Color.white.opacity(0.78))
                    .lineLimit(1)

                InverseCardTag(tag: item.book.genres.first?.name ?? item.shelf.title)

                if let progress = item.progress {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(progressLabel(progress))
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(Color.white.opacity(0.92))

                        ProgressView(value: progressFraction(progress))
                            .tint(Color(red: 0.84, green: 0.91, blue: 0.82))
                    }
                }
            }

            Spacer(minLength: 0)

            RemoteCoverView(url: item.book.coverURL, width: 116, height: 168)
                .rotationEffect(.degrees(2))
                .shadow(color: Color.black.opacity(0.12), radius: 16, x: 0, y: 10)
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.38, green: 0.48, blue: 0.37),
                            Color(red: 0.29, green: 0.37, blue: 0.28)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(Color.white.opacity(0.16), lineWidth: 1)
        )
    }

    private func progressLabel(_ progress: ReadingProgress) -> String {
        switch progress.progressUnit {
        case .page:
            return "Page \(progress.progressValue)"
        case .percent:
            return "\(progress.progressValue)% complete"
        }
    }

    private func progressFraction(_ progress: ReadingProgress) -> Double {
        switch progress.progressUnit {
        case .page:
            guard let pageCount = item.book.pageCount, pageCount > 0 else { return 0.3 }
            return min(max(Double(progress.progressValue) / Double(pageCount), 0), 1)
        case .percent:
            return min(max(Double(progress.progressValue) / 100, 0), 1)
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

private struct MoodBookCard: View {
    let book: Book
    let moodTitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            RemoteCoverView(url: book.coverURL, width: 136, height: 194)

            VStack(alignment: .leading, spacing: 7) {
                Text(book.title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                Text(book.authors.map(\.name).joined(separator: ", "))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                CardTagRow(tag: book.genres.first?.name ?? moodTitle)
            }
        }
        .frame(width: 140, alignment: .leading)
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

private struct InverseCardTag: View {
    let tag: String

    var body: some View {
        Text(tag)
            .font(.caption2.weight(.medium))
            .foregroundStyle(Color.white.opacity(0.92))
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(Color.white.opacity(0.12), in: Capsule())
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

private extension Array {
    subscript(safe index: Int) -> Element? {
        guard indices.contains(index) else { return nil }
        return self[index]
    }
}
