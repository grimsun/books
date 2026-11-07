import SwiftUI

struct BookSummaryCard<Header: View, Footer: View>: View {
    let book: Book
    let coverWidth: CGFloat
    let coverHeight: CGFloat
    let textSpacing: CGFloat
    private let header: Header
    private let footer: Footer

    init(
        book: Book,
        coverWidth: CGFloat = 94,
        coverHeight: CGFloat = 136,
        textSpacing: CGFloat = 7,
        @ViewBuilder header: () -> Header,
        @ViewBuilder footer: () -> Footer
    ) {
        self.book = book
        self.coverWidth = coverWidth
        self.coverHeight = coverHeight
        self.textSpacing = textSpacing
        self.header = header()
        self.footer = footer()
    }

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            RemoteCoverView(url: book.coverURL, width: coverWidth, height: coverHeight)
                .coverShadow()

            VStack(alignment: .leading, spacing: textSpacing) {
                header

                Text(book.title)
                    .font(.system(size: 20, weight: .semibold, design: .rounded))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)

                Text(book.authors.map(\.name).joined(separator: ", "))
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)

                footer

                Spacer(minLength: 0)
            }
            .fixedSize(horizontal: false, vertical: true)

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
