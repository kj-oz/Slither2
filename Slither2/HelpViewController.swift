//
//  HelpViewController.swift
//  Slither2
//
//  Created by KO on 2019/04/29.
//  Copyright © 2019 KO. All rights reserved.
//

import UIKit

class HelpViewController: UIViewController, UIWebViewDelegate {
  // webビュー
  @IBOutlet weak var webView: UIWebView!
  
  // 表示するヘルプHTMLのURL
  var url: URL?
  
  // MARK: - UIViewController
  
  // ビューロード時
  override func viewDidLoad() {
    super.viewDidLoad()
    webView.delegate = self
  }
  
  // ビュー表示直前
  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    if let url = url {
      webView?.loadRequest(URLRequest(url: url))
    }
  }

  // MARK: - UIWebViewDelegate
  
  // 新しいアドレスへの移動の直前
  func webView(_ webView: UIWebView, shouldStartLoadWith request: URLRequest, navigationType: UIWebView.NavigationType) -> Bool {
    if let url = request.url, !url.isFileURL {
      if UIApplication.shared.canOpenURL(url) {
        UIApplication.shared.openURL(url)
        return false
      }
    }
    return true
  }
}
