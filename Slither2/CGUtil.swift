//
//  CGUtil.swift
//  Slither2
//
//  Created by KO on 2019/01/03.
//  Copyright © 2019 KO. All rights reserved.
//

import Foundation
import CoreGraphics

/// CGPointの引き算
///
/// - Parameters:
///   - pt1: ポイント1
///   - pt2: ポイント2
/// - Returns: ポイント1 − ポイント2
public func subtract(pt1: CGPoint, pt2: CGPoint) -> CGPoint {
  return CGPoint(x: pt1.x - pt2.x, y: pt1.y - pt2.y)
}

/// CGFloatの値を指定の範囲に収まるように修正した値を得る
///
/// - Parameters:
///   - value: 対象の値
///   - min: 範囲下限
///   - max: 範囲上限
/// - Returns: 範囲内に丸められた値
public func clumpValue(value: CGFloat, min: CGFloat, max: CGFloat) -> CGFloat {
  return value < min ? min : value > max ? max : value
}

/// 整数値を指定の範囲に収まるようにした値を得る
///
/// - Parameters:
///   - value: 対象の値
///   - min: 範囲下限
///   - max: 範囲上限
/// - Returns: 範囲内に丸められた値
public func clumpInt(value: Int, min: Int, max: Int) -> Int {
  return value < min ? min : value > max ? max : value
}

/// CGRectを指定の領域内に入るように修正したCGRectを得る
///
/// - Parameters:
///   - rect: 対象のCGRect
///   - border: 可能範囲
/// - Returns: 範囲内に丸められたCGRect
public func clumpRect(rect: CGRect, border: CGRect) -> CGRect {
  let x = rect.size.width > border.size.width ? border.origin.x :
    clumpValue(value: rect.origin.x, min: border.origin.x, max: border.maxX - rect.size.width)
  let y = rect.size.height > border.size.height ? border.origin.y :
    clumpValue(value: rect.origin.y, min: border.origin.y, max: border.maxY - rect.size.height)
  return CGRect(x: x, y: y, width: rect.size.width, height: rect.size.height)
}
