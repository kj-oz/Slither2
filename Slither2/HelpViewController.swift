//
//  HelpViewController.swift
//  Slither2
//
//  Created by KO on 2019/04/29.
//  Copyright © 2019 KO. All rights reserved.
//

import UIKit

class HelpViewController: UIViewController, UIWebViewDelegate {
  
  
  @IBOutlet weak var webView: UIWebView!
  
  var url: URL?
  
  override func viewDidLoad() {
    super.viewDidLoad()
    webView.delegate = self
  }
  
  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    if let url = url {
      webView?.loadRequest(URLRequest(url: url))
    }
  }

  //pragma mark UIWebDelegate
  
  func webView(_ webView: UIWebView, shouldStartLoadWith request: URLRequest, navigationType: UIWebView.NavigationType) -> Bool {
    let url: URL? = request.url
    if url?.isFileURL == nil {
      if let url = url {
        if UIApplication.shared.canOpenURL(url) {
          UIApplication.shared.openURL(url)
          return false
        }
      }
    }
    return true
  }
}
