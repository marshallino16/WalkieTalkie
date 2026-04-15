import SwiftUI

struct SpeakerGrilleView: View {
    let rows: Int
    let columns: Int
    let dotColor: Color

    init(rows: Int = 12, columns: Int = 8, dotColor: Color = WTTheme.yellowDark) {
        self.rows = rows
        self.columns = columns
        self.dotColor = dotColor
    }

    var body: some View {
        Canvas { context, size in
            let spacingX = size.width / CGFloat(columns + 1)
            let spacingY = size.height / CGFloat(rows + 1)
            let dotRadius = min(spacingX, spacingY) * 0.25

            for row in 1...rows {
                for col in 1...columns {
                    let x = spacingX * CGFloat(col)
                    let y = spacingY * CGFloat(row)
                    let rect = CGRect(
                        x: x - dotRadius,
                        y: y - dotRadius,
                        width: dotRadius * 2,
                        height: dotRadius * 2
                    )
                    context.fill(Circle().path(in: rect), with: .color(dotColor))
                }
            }
        }
    }
}
