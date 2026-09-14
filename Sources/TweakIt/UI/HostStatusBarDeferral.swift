//
//  HostStatusBarDeferral.swift
//  TweakIt
//
//  Keeps TweakIt's overlay windows from answering a question they have no
//  opinion about.
//
//  THE BUG THIS FIXES. UIKit does not ask the KEY window about the status
//  bar — it asks the TOPMOST window that has a root view controller. Both
//  of TweakIt's windows sit above the app (`.normal + 9` for the button,
//  `+ 10` for the panel), both have root view controllers from the moment
//  `setup()` runs, and neither had any view on the matter. So a host app
//  that asked for a hidden status bar got this:
//
//      UIWindow            level 0    prefersStatusBarHidden = true
//      PassThroughWindow   level 9    prefersStatusBarHidden = false
//      PanelWindow         level 10   prefersStatusBarHidden = false
//
//  and the false won. The app's own modifier — SwiftUI's
//  `.statusBarHidden`, or a plain `prefersStatusBarHidden` override — was
//  simply overruled by a debugging tool it had installed, with no error and
//  no way to tell from the app's side. (Found from the Droog side, where it
//  cost an afternoon: every placement of `.statusBarHidden` was ruled out,
//  including on the scene root with no modal involved, before anyone
//  thought to enumerate the windows.)
//
//  The fix is not for TweakIt to have an opinion. It is to look down at the
//  app's own window and repeat whatever it said. An overlay that draws a
//  floating button has no business changing the status bar, and now it
//  cannot.
//

#if canImport(UIKit)
import UIKit

@available(iOS 16.0, *)
enum HostStatusBar {

    /// The HOST app's root view controller: the topmost visible window at
    /// the ordinary window level, which is everything TweakIt is not.
    ///
    /// Filtering by level is what keeps this from finding itself — both
    /// TweakIt windows live above `.normal` — and the type check is a belt
    /// on top of it, in case a future overlay forgets to raise its level.
    static func hostRootViewController(near window: UIWindow?) -> UIViewController? {
        guard let scene = window?.windowScene else { return nil }
        return scene.windows
            .filter { candidate in
                !candidate.isHidden
                    && candidate.windowLevel == .normal
                    && !(candidate is PassThroughWindow)
            }
            .last?
            .rootViewController
    }

    /// Follow the host's OWN deferral chain to the controller that actually
    /// answers. A `UIHostingController` hands the question down to a child
    /// (or to whatever it has presented), and reading `prefersStatusBarHidden`
    /// off the root alone would get the root's default instead of the answer
    /// the app meant.
    static func hostResponder(near window: UIWindow?,
                              chain: (UIViewController) -> UIViewController?) -> UIViewController? {
        guard var node = hostRootViewController(near: window) else { return nil }
        // Bounded: a malformed chain must not spin. 32 is far past any real
        // hierarchy and still cheap.
        for _ in 0..<32 {
            if let presented = node.presentedViewController {
                node = presented
                continue
            }
            guard let next = chain(node) else { return node }
            node = next
        }
        return node
    }
}
#endif

#if canImport(UIKit)
import SwiftUI

/// The button window's root controller. Identical to `UIHostingController`
/// except that it has no opinion about the status bar or the home
/// indicator — it repeats the host app's.
///
/// This exists because the button window is ALWAYS up (that is the point of
/// a floating tweak button), so without it every app that installs TweakIt
/// silently loses the ability to hide its own status bar for the whole
/// session.
@available(iOS 16.0, *)
final class HostStatusBarDeferringHostingController<Content: View>: UIHostingController<Content> {

    override var prefersStatusBarHidden: Bool {
        HostStatusBar.hostResponder(near: view.window) { $0.childForStatusBarHidden }?
            .prefersStatusBarHidden ?? super.prefersStatusBarHidden
    }

    override var preferredStatusBarStyle: UIStatusBarStyle {
        HostStatusBar.hostResponder(near: view.window) { $0.childForStatusBarStyle }?
            .preferredStatusBarStyle ?? super.preferredStatusBarStyle
    }

    override var prefersHomeIndicatorAutoHidden: Bool {
        HostStatusBar.hostResponder(near: view.window) { $0.childForHomeIndicatorAutoHidden }?
            .prefersHomeIndicatorAutoHidden ?? super.prefersHomeIndicatorAutoHidden
    }

    // Nil, or SwiftUI's own hosting machinery takes the question back and
    // answers it with this controller's defaults — which is the behaviour
    // being fixed.
    override var childForStatusBarHidden: UIViewController? { nil }
    override var childForStatusBarStyle: UIViewController? { nil }
    override var childForHomeIndicatorAutoHidden: UIViewController? { nil }
}
#endif
