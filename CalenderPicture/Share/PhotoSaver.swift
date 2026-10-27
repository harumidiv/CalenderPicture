//
//  PhotoSaver.swift
//  CalenderPicture
//
//  書き出した画像を写真ライブラリに保存する（追加だけの許可で足りる）。
//

import Photos
import UIKit

enum PhotoSaver {
    /// 保存して、結果を知らせる文を返す
    static func save(_ image: UIImage) async -> String {
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard status == .authorized || status == .limited else { return "写真への保存が許可されていません" }
        do {
            try await PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.creationRequestForAsset(from: image)
            }
            return "写真に保存しました"
        } catch {
            return "保存できませんでした"
        }
    }
}
