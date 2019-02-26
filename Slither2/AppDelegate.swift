//
//  AppDelegate.swift
//  Slither
//
//  Created by KO on 2018/09/19.
//  Copyright © 2018年 KO. All rights reserved.
//

import UIKit

/// アプリケーション・デリゲート
@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
  /// ウィンドウ
  var window: UIWindow?

  /// アプリケーションマネージャ
  var am: AppManager!

  // アプリ起動時
  func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
    // 前回の状態などを読み込む
    am = AppManager.sharedInstance
    am.restoring = true
    return true
  }

  // バックグラウンドにまわる直前
  func applicationWillResignActive(_ application: UIApplication) {
    let n = Notification(name: NSNotification.Name("applicationWillResignActive"), object: self)
    NotificationCenter.default.post(n)
  }

  // バックグラウンドにまわった直後
  func applicationDidEnterBackground(_ application: UIApplication) {
    let n = Notification(name: NSNotification.Name("applicationDidEnterBackground"), object: self)
    NotificationCenter.default.post(n)
    // 状態の保存
    am.saveStatus()
  }

  // フォアグラウンドにまわる直前
  func applicationWillEnterForeground(_ application: UIApplication) {
    let n = Notification(name: NSNotification.Name("applicationWillEnterForeground"), object: self)
    NotificationCenter.default.post(n)
  }

  // フォアグラウンドにまわった直後
  func applicationDidBecomeActive(_ application: UIApplication) {
    let n = Notification(name: NSNotification.Name("applicationDidBecomeActive"), object: self)
    NotificationCenter.default.post(n)
  }

  // アプリ終了時
  func applicationWillTerminate(_ application: UIApplication) {
    // 状態の保存
    am.saveStatus()
  }
}

