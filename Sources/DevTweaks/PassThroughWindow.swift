//
//  PassThroughWindow.swift
//  DevTweaks
//
//  A UIWindow that passes touches through transparent areas.
//

import UIKit

/// A UIWindow subclass that allows touches to pass through transparent areas.
/// Used for floating buttons and overlay UIs that shouldn't block interaction.
public class PassThroughWindow: UIWindow {
    public override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        for subview in rootViewController?.view.subviews ?? [] {
            if !subview.isHidden && subview.isUserInteractionEnabled && subview.point(inside: convert(point, to: subview), with: event) {
                return true
            }
        }
        return false
    }
}
