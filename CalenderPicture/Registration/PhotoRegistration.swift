//
//  PhotoRegistration.swift
//  CalenderPicture
//
//  写真ピッカーを開いて写真を選び、登録シートで確認して登録するまでの流れ。
//

import PhotosUI
import SwiftUI

/// 写真を選んで登録したい日。同じ日でも頼むたびに別の値になるので、続けて頼んでもピッカーが開く
struct PhotoRequest: Equatable {
    let id = UUID()
    let day: DayKey
}

/// 写真を選んだあとの登録シートの内容
struct PendingRegistration: Identifiable {
    let id = UUID()
    let day: DayKey
    let item: PhotosPickerItem
}

private struct PhotoRegistrationModifier: ViewModifier {
    @Binding var request: PhotoRequest?

    @State private var isPickerPresented = false
    @State private var pickedItem: PhotosPickerItem?
    @State private var registration: PendingRegistration?

    func body(content: Content) -> some View {
        content
            .photosPicker(isPresented: $isPickerPresented, selection: $pickedItem, matching: .images)
            .onChange(of: request) { _, request in
                if request != nil { isPickerPresented = true }
            }
            // ピッカーが閉じたあとに選択結果が届くので、登録先の日は request に残しておく
            .onChange(of: pickedItem) { _, item in
                guard let item, let day = request?.day else { return }
                registration = PendingRegistration(day: day, item: item)
                pickedItem = nil
                request = nil
            }
            .sheet(item: $registration) { pending in
                RegistrationView(day: pending.day, item: pending.item) { registration = nil }
            }
    }
}

extension View {
    /// `request` に日を入れると写真ピッカーを開き、選んだ写真をその日に登録する
    func photoRegistration(_ request: Binding<PhotoRequest?>) -> some View {
        modifier(PhotoRegistrationModifier(request: request))
    }
}
