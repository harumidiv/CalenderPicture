//
//  PaintStylePicker.swift
//  CalenderPicture
//
//  起動時に出す、写真をどの塗り方の絵にするかを選ぶシート。前回選んだものに印をつけておく。
//  自分の写真をすべての塗り方で描いて見比べる画面（PaintStyleComparison）も開ける。
//

import SwiftUI

struct PaintStylePicker: View {
    @AppStorage(PaintStyle.storageKey) private var style: PaintStyle = .crayon
    let onFinish: () -> Void
    @State private var showsComparison = false

    private let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                VStack(spacing: 4) {
                    Text("どの塗り方で描く？")
                        .font(.system(.title3, design: .rounded).weight(.bold))
                    Text("これから登録する写真に使います")
                        .font(.system(.footnote, design: .rounded))
                        .foregroundStyle(.secondary)
                }

                Button("自分の写真で見比べる", systemImage: "square.grid.2x2") { showsComparison = true }
                    .buttonStyle(.pill)
                    .accessibilityIdentifier("paint-style-compare")

                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(PaintStyle.allCases) { option in
                        Button {
                            style = option
                            onFinish()
                        } label: {
                            tile(option, isSelected: option == style)
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(option == style ? .isSelected : [])
                        .accessibilityIdentifier("paint-style-\(option.rawValue)")
                    }
                }
            }
            .padding(24)
        }
        .background(DoodStyle.background.ignoresSafeArea())
        .fullScreenCover(isPresented: $showsComparison) {
            PaintStyleComparison(current: style) { chosen in
                style = chosen
                showsComparison = false
                onFinish()
            } onClose: {
                showsComparison = false
            }
        }
    }

    private func tile(_ option: PaintStyle, isSelected: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: option.systemImage)
                    .font(.system(size: 20, weight: .semibold))
                    .frame(width: 40, height: 40)
                    .background(DoodStyle.background, in: .circle)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title3)
                }
            }
            Text(option.title)
                .font(.system(.body, design: .rounded).weight(.semibold))
            Text(option.subtitle)
                .font(.system(.caption, design: .rounded))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, minHeight: 130, alignment: .topLeading)
        .padding(14)
        .background(DoodStyle.surface, in: .rect(cornerRadius: 16))
        .overlay {
            if isSelected {
                RoundedRectangle(cornerRadius: 16).strokeBorder(Color.primary, lineWidth: 2)
            }
        }
        .shadow(color: DoodStyle.shadowColor, radius: 10, y: 4)
        .contentShape(.rect(cornerRadius: 16))
    }
}

#Preview {
    PaintStylePicker {}
}
