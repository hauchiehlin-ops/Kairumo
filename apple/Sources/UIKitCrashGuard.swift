//
//  UIKitCrashGuard.swift
//  Kairumo
//
//  防禦 iOS / UIKit 系統級缺陷與私有 Selector 派發例外
//

#if canImport(UIKit)
import Foundation
import UIKit

extension NSObject {
    /// 防禦 iOS 系統在鍵盤最小化 / 收起時的內部缺陷：
    /// `UITrackingElementWindowController.changeToInputViewSet:` 會對 inputViewSet 中的所有物件呼叫
    /// `makeObjectsPerformSelector:@selector(initializeTranslateGestureRecognizerIfNecessary)`。
    /// 當集合內含有非視圖的 `UITextInputTraits` 物件時，UIKit 會因該物件未實作該 selector
    /// 而拋出 `NSInvalidArgumentException`（unrecognized selector sent to instance）導致 App 崩潰。
    ///
    /// 在 NSObject 層提供安全空實作（no-op fallback），若子類別已有實作則依 ObjC 動態派發優先調用子類別，
    /// 若無實作則安全退回此處，避免未捕獲例外觸發 SIGABRT / Crash。
    @objc func initializeTranslateGestureRecognizerIfNecessary() {
        // No-op fallback to absorb UIKit private selector dispatch bug
    }
}
#endif
