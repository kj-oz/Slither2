//
//  CGUtil.swift
//  Slither
//
//  Created by KO on 2019/01/03.
//  Copyright © 2019 KO. All rights reserved.
//

import Foundation
import CoreGraphics

public func subtract(pt1: CGPoint, pt2: CGPoint) -> CGPoint {
  return CGPoint(x: pt1.x - pt2.x, y: pt1.y - pt2.y)
}

public func clumpValue(value: CGFloat, min: CGFloat, max: CGFloat) -> CGFloat {
  return value < min ? min : value > max ? max : value
}

public func clumpInt(value: Int, min: Int, max: Int) -> Int {
  return value < min ? min : value > max ? max : value
}

public func clumpRect(rect: CGRect, border: CGRect) -> CGRect {
  let x = rect.size.width > border.size.width ? border.origin.x :
    clumpValue(value: rect.origin.x, min: border.origin.x, max: border.maxX - rect.size.width)
  let y = rect.size.height > border.size.height ? border.origin.y :
    clumpValue(value: rect.origin.y, min: border.origin.y, max: border.maxY - rect.size.height)
  return CGRect(x: x, y: y, width: rect.size.width, height: rect.size.height)
}
