import UIKit
import WebKit

/// A `WKWebView` with no keyboard accessory bar.
///
/// iOS puts a previous/next/Done bar above the keyboard for any focused text
/// field. In a game that is noise, and with a hardware keyboard — on a Mac, or
/// an iPad with a case — the keyboard itself never appears, so the bar shows up
/// as a stray grey slab pinned to the bottom of the window.
///
/// The accessory belongs to WebKit's private content view rather than to the
/// web view, so it cannot simply be overridden. Instead, subclass that view's
/// class at runtime and return nil from the subclass, which is the long-standing
/// way to do this without touching private API.
final class KeyboardAccessoryFreeWebView: WKWebView {
    private static var patchedClasses: [String: AnyClass] = [:]

    override func becomeFirstResponder() -> Bool {
        removeAccessoryBar()
        return super.becomeFirstResponder()
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        removeAccessoryBar()
    }

    private func removeAccessoryBar() {
        guard let contentView = scrollView.subviews.first(where: {
            String(describing: type(of: $0)).hasPrefix("WKContentView")
        }) else { return }

        let originalClass: AnyClass = type(of: contentView)
        let originalName = NSStringFromClass(originalClass)
        guard !originalName.hasSuffix("_NoAccessory") else { return }

        let patched: AnyClass
        if let cached = Self.patchedClasses[originalName] {
            patched = cached
        } else {
            let patchedName = originalName + "_NoAccessory"
            guard let created = objc_allocateClassPair(originalClass, patchedName, 0) else { return }

            let selector = #selector(getter: UIResponder.inputAccessoryView)
            let block: @convention(block) (AnyObject) -> UIView? = { _ in nil }
            if let method = class_getInstanceMethod(UIResponder.self, selector) {
                class_addMethod(
                    created,
                    selector,
                    imp_implementationWithBlock(block),
                    method_getTypeEncoding(method)
                )
            }

            objc_registerClassPair(created)
            Self.patchedClasses[originalName] = created
            patched = created
        }

        object_setClass(contentView, patched)
    }
}
