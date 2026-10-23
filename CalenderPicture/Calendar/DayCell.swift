//
//  DayCell.swift
//  CalenderPicture
//
//  カレンダーの1マス。登録済みならクレヨン画のサムネイルを敷く。
//

import SwiftUI
import UIKit

struct DayCell: View {
    static let aspectRatio: CGFloat = 0.78

    let day: Int
    /// クレヨン画のデータ。削除済みのモデルを非同期処理から触らないよう、モデルではなく値で受け取る
    let drawingData: Data?
    /// サムネイルを作り直すきっかけ（更新日時）
    let version: Date?
    let isToday: Bool

    private var isRegistered: Bool { drawingData != nil }

    @State private var thumbnail: UIImage?

    var body: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(isRegistered ? .white : Color(.secondarySystemBackground))
            .aspectRatio(Self.aspectRatio, contentMode: .fit)
            .overlay {
                if let thumbnail {
                    Image(uiImage: thumbnail)
                        .resizable()
                        .scaledToFill()
                }
            }
            .clipShape(.rect(cornerRadius: 8))
            .overlay(alignment: .topLeading) {
                Text("\(day)")
                    .font(.caption2.weight(.bold))
                    .monospacedDigit()
                    .foregroundStyle(isToday ? .white : .primary)
                    .frame(minWidth: 18, minHeight: 18)
                    .background {
                        if isToday {
                            Circle().fill(.tint)
                        } else if isRegistered {
                            Circle().fill(.background.opacity(0.85))
                        }
                    }
                    .padding(3)
            }
            .shadow(color: .black.opacity(isRegistered ? 0.12 : 0), radius: 2, y: 1)
            .contentShape(.rect)
            .task(id: version) {
                thumbnail = await Self.makeThumbnail(from: drawingData)
            }
    }

    private static func makeThumbnail(from data: Data?) async -> UIImage? {
        guard let data else { return nil }
        return await Task.detached(priority: .utility) {
            await UIImage(data: data)?.byPreparingThumbnail(ofSize: CGSize(width: 160, height: 160))
        }.value
    }
}
