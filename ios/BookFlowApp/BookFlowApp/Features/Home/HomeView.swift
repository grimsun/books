import SwiftUI

struct HomeView: View {
    let environment: AppEnvironment

    @State private var recommendations: [RecommendationItem] = []

    var body: some View {
        List {
            Section {
                Text("Personal picks based on your library, genres, and finish history.")
                    .foregroundStyle(.secondary)
            }

            Section("For You") {
                ForEach(recommendations) { item in
                    NavigationLink {
                        BookDetailView(environment: environment, bookID: item.book.id, recommendationReason: item.reason)
                    } label: {
                        RecommendationRow(item: item)
                    }
                }
            }
        }
        .navigationTitle("Home")
        .task {
            if recommendations.isEmpty {
                recommendations = (try? await environment.recommendationsRepository.fetchRecommendations()) ?? []
            }
        }
    }
}

private struct RecommendationRow: View {
    let item: RecommendationItem

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            RemoteCoverView(url: item.book.coverURL)

            VStack(alignment: .leading, spacing: 6) {
                Text(item.book.title)
                    .font(.headline)
                Text(item.book.authors.map(\.name).joined(separator: ", "))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(item.reason)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.top, 2)
            }
        }
        .padding(.vertical, 4)
    }
}
