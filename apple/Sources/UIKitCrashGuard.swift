//
//  UIKitCrashGuard.swift
//  Kairumo
//
//  防禦 iOS / UIKit 系統級缺陷與私有 Selector 派發例外
//

#if canImport(UIKit)
import Foundation
import UIKit
import ObjectiveC

public enum UIKitCrashGuard {
    // profile-scope: device 整台裝置共用，跨設定檔安裝一次
    private static var isAssertionGuardInstalled = false

    /// 安裝系統級例外與斷言防禦鉤子
    public static func install() {
        installAssertionGuard()
    }

    /// 防禦 Mac Catalyst / UIKitMacHelper 在全螢幕轉換或視窗狀態還原時的內部斷言缺陷：
    /// `-[UINSUIKitBackgroundingController _enqueueStateThawingIfNecessaryAndDequeue:]`
    /// 在 App 剛啟動或視窗從 savedState 還原時，若收到 AppKit 的 `NSWindowDidEnterFullScreenNotification`
    /// 卻未經歷對應的凍結階段（freeze count == 0），會觸發斷言：
    /// `NSInternalInconsistencyException: Unbalanced state change freezing/thawing!` 並直接 abort()。
    ///
    /// 透過全域攔截 `NSAssertionHandler` 的方法與函數斷言分派，在檢測到此類已知的系統框架內部時序不平衡斷言時，
    /// 予以安全吸收並記錄警告，防止整個 App 異常終止。
    private static func installAssertionGuard() {
        guard !isAssertionGuardInstalled else { return }
        isAssertionGuardInstalled = true

        let selMethod = NSSelectorFromString("handleFailureInMethod:object:file:lineNumber:description:")
        if let method = class_getInstanceMethod(NSAssertionHandler.self, selMethod) {
            typealias OriginalIMP = @convention(c) (AnyObject, Selector, Selector, AnyObject?, NSString?, Int, NSString?) -> Void
            var origIMP: IMP?

            let hook: @convention(block) (AnyObject, Selector, AnyObject?, NSString?, Int, NSString?) -> Void = {
                (selfObj, selector, object, fileName, line, format) in
                let file = (fileName as String?) ?? ""
                let msg = (format as String?) ?? ""
                if file.contains("UINSUIKitBackgroundingController") || msg.contains("freezing/thawing") {
                    #if DEBUG
                    print("🛡️ [UIKitCrashGuard] Absorbed UIKitMacHelper assertion: \(file):\(line) - \(msg)")
                    #endif
                    return
                }
                if let orig = origIMP {
                    let fn = unsafeBitCast(orig, to: OriginalIMP.self)
                    fn(selfObj, selMethod, selector, object, fileName, line, format)
                }
            }

            let newIMP = imp_implementationWithBlock(hook)
            origIMP = method_setImplementation(method, newIMP)
        }

        let selFunc = NSSelectorFromString("handleFailureInFunction:file:lineNumber:description:")
        if let method = class_getInstanceMethod(NSAssertionHandler.self, selFunc) {
            typealias OriginalFuncIMP = @convention(c) (AnyObject, Selector, NSString?, NSString?, Int, NSString?) -> Void
            var origFuncIMP: IMP?

            let hookFunc: @convention(block) (AnyObject, NSString?, NSString?, Int, NSString?) -> Void = {
                (selfObj, funcName, fileName, line, format) in
                let file = (fileName as String?) ?? ""
                let msg = (format as String?) ?? ""
                if file.contains("UINSUIKitBackgroundingController") || msg.contains("freezing/thawing") {
                    #if DEBUG
                    print("🛡️ [UIKitCrashGuard] Absorbed UIKitMacHelper function assertion: \(file):\(line) - \(msg)")
                    #endif
                    return
                }
                if let orig = origFuncIMP {
                    let fn = unsafeBitCast(orig, to: OriginalFuncIMP.self)
                    fn(selfObj, selFunc, funcName, fileName, line, format)
                }
            }

            let newIMP = imp_implementationWithBlock(hookFunc)
            origFuncIMP = method_setImplementation(method, newIMP)
        }
    }
}

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
