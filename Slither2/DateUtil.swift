
//
//  DateUtil.swift
//  KLibrary
//
//  Created by KO on 2015/01/03.
//  Copyright (c) 2019年 KO. All rights reserved.
//

import Foundation

/** 
 * NSDateへのユーティリティ関数の追加
 */
extension Date {
  /** 年から秒までの全ての要素の値 */
  public var components: DateComponents {
    let flags: NSCalendar.Unit = [NSCalendar.Unit.year, NSCalendar.Unit.month, NSCalendar.Unit.day, NSCalendar.Unit.hour, NSCalendar.Unit.minute, NSCalendar.Unit.second]
    return (Calendar.current as NSCalendar).components(flags, from: self)
  }
  
  /** 時(整数) */
  public var hour: Int {
    let flags = NSCalendar.Unit.hour
    let comps = (Calendar.current as NSCalendar).components(flags, from: self)
    return comps.hour!
  }
  
  /** 分(整数) */
  public var minute: Int {
    let flags = NSCalendar.Unit.minute
    let comps = (Calendar.current as NSCalendar).components(flags, from: self)
    return comps.minute!
  }
  
  /** yyyy/MM/dd HH:mm:ss 形式の文字列 */
  public var simpleString: String {
    let df = DateFormatter()
    df.dateFormat = "yyyy/MM/dd HH:mm:ss"
    return df.string(from: self)
  }
  
  /** yyyy/MM/dd 形式の日付文字列 */
  public var dateString: String {
    let df = DateFormatter()
    df.dateFormat = "yyyy/MM/dd"
    return df.string(from: self)
  }
  
  /** MM/dd HH:mm 形式の文字列 */
  public var mdhm: String {
    let df = DateFormatter()
    df.dateFormat = "MM/dd HH:mm"
    return df.string(from: self)
  }
  
  /** 年月日の整数(yyyyMMdd) */
  public var dateInt: Int {
    let comps = components
    return comps.year! * 10000 + comps.month! * 100 + comps.day!
  }
  
  /**
   * 年月日整数の表す日付のNSDateオブジェクトを得る
   *
   * - parameter dateInt: 年月日整数
   * - returns: NSDateオブジェクト
   */
  public static func fromInt(_ dateInt: Int) -> Date? {
    var comps = DateComponents()
    comps.year = dateInt / 10000
    let monthday = dateInt % 10000
    comps.month = monthday / 100
    comps.day = monthday % 100
    
    return Calendar.current.date(from: comps)
  }
  
  /** 
   * 年月日整数に指定の日数を加えた年月日整数を返す
   *
   * - parameter days: 加える日数
   * - parameter toDate: 元の年月日整数
   * - returns: 日数を加えた年月日整数
   */
  public static func addToDateInt(_ days: Int, toDate: Int) -> Int {
    let date = Date.fromInt(toDate)
    let result = date?.addingTimeInterval(Double(days) * 60.0 * 60 * 24)
    return result!.dateInt
  }
  
  /**
   * 与えられた整数表現の日付の翌日の日付を得る
   *
   * - parameter date: 日付
   * - returns: 次の日の日付
   */
  public static func tommorow(_ date: Int) -> Int {
    return Date.addToDateInt(1, toDate: date)
  }
  
  /**
   * ２つの年月日整数の差の日数を返す
   *
   * - parameter date1: 年月日整数1
   * - parameter date2: 年月日整数2
   * - returns: ２つの年月日整数の差(date1-date2）
   */
  public static func dateIntDiff(_ date1: Int, _ date2: Int) -> Int {
    let nsdate1 = Date.fromInt(date1)
    let nsdate2 = Date.fromInt(date2)
    let diff = nsdate1!.timeIntervalSince(nsdate2!)
    return Int(diff) / (60 * 60 * 24)
  }

  /**
   * ちょうど0時0分のNSDateオブジェクトを返す
   *
   * - parameter before: 現在より前の0時0分かどか
   * - returns: ちょうど0時0分のNSDateオブジェクト
   */
  public func roundToDay(before: Bool = true) -> Date {
    var comps = self.components
    if comps.hour == 0 && comps.minute == 0 && comps.second == 0 {
      return self
    }
    comps.hour = 0
    comps.minute = 0
    comps.second = 0
    var roundedDate = Calendar.current.date(from: comps)!
    if !before {
      roundedDate = roundedDate.addingTimeInterval(24 * 60 * 60)
    }
    return roundedDate
  }
  
  /**
   * ちょうど0分のNSDateオブジェクトを返す
   *
   * - parameter before: 現在より前の0分かどか
   * - returns: ちょうど0分のNSDateオブジェクト
   */
  public func roundToHour(_ before: Bool = true) -> Date {
    var comps = self.components
    if comps.minute == 0 && comps.second == 0 {
      return self
    }
    comps.minute = 0
    comps.second = 0
    var roundedDate = Calendar.current.date(from: comps)!
    if !before {
      roundedDate = roundedDate.addingTimeInterval(60 * 60)
    }
    return roundedDate
  }
}

open class DateUtil {
}
