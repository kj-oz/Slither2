//
//  Logger.swift
//  KLibrary
//
//  Created by KO on 2015/01/16.
//  Copyright (c) 2019年 KO. All rights reserved.
//

import Foundation

/**
 * ローテーション可能なログファイル
 */
open class Logger {
  
  /** ログを保存するディレクトリ */
  fileprivate let dir: String
  
  /** ログファイル名の先頭につく固定文字列 */
  fileprivate let prefix: String
  
  /** 何日でローテーションするか */
  fileprivate let rotationDays: Int
  
  /** ローテション後のログファイルを何世代保存するか */
  fileprivate let maxBackups: Int
  
  /** ファイルハンドル */
  fileprivate var fileHandle: FileHandle?
  
  /** ログファイルのパス */
  fileprivate var path = ""
  
  /** 次にローテションする日付(整数) */
  fileprivate var rotationDate = 0
  
  /** ファイルの内容 */
  open var contents: String? {
    let files = listFiles()
    
    var contentList = [String]()
    for file in files {
      if let fileContent = try? NSString(contentsOfFile: (dir as NSString).appendingPathComponent(file),
          encoding: String.Encoding.utf8.rawValue) {
        contentList.append(String(fileContent))
      }
    }
    
    if contentList.count > 0 {
      return contentList.joined(separator: "")
    } else {
      return nil
    }
  }
  
  /**
   * ログファイルのインスタンスを生成する
   *
   * - parameter dir: ログを保存するディレクトリ
   * - parameter prefix: ログファイル名の先頭につく固定文字列
   * - parameter rotationDays: 何日でローテーションするか
   * - parameter maxBackups: ローテション後のログファイルを何世代保存するか
   */
  public init(dir: String, prefix: String, rotationDays: Int, maxBackups: Int) {
    self.dir = dir
    self.prefix = prefix
    self.rotationDays = rotationDays
    self.maxBackups = maxBackups
    
    let files = listFiles()
    
    let startDay: Int
    let fileName: String
    if files.count > 0 {
      fileName = files.last!
      startDay = extractDateFromFileName(fileName)
    } else {
      startDay = Date().dateInt
      fileName = createFile(startDay)
    }
    
    rotationDate = dateForRotation(startDay)
    path = (dir as NSString).appendingPathComponent(fileName)
    fileHandle = FileHandle(forWritingAtPath: path)
    if let fileHandle = fileHandle {
      fileHandle.seekToEndOfFile()
    }
  }
  
  // 破棄時に呼び出される
  deinit {
    closeFile()
  }
  
  /**
   * ログを記入する（与えれらた文字列の前に日時が挿入される）
   *
   * - parameter log: ログ文字列
   */
  open func log(_ log: String) {
    let today = Date().dateInt
    while today >= rotationDate {
      rotateFile()
    }
    if let fileHandle = fileHandle {
      let output = Date().simpleString + " " + log + "\n"
      let data = output.data(using: String.Encoding.utf8, allowLossyConversion: false)
      print(output, terminator: "")
      fileHandle.write(data!)
    }
  }
  
  /**
   * ファイル名から日付(整数）を得る
   *
   * - parameter fileName: ファイル名
   * - returns: 日付(整数）
   */
  fileprivate func extractDateFromFileName(_ fileName: String) -> Int {
    let name = (fileName as NSString).deletingPathExtension
    let num = name[name.index(name.startIndex, offsetBy: prefix.count)...]
    return Int(num)!
  }
  
  /**
   * 所定のディレクトリーの下のログファイルのリストを得る
   *
   * - returns: ログファイル名の配列
   */
  fileprivate func listFiles() -> [String] {
    return FileUtil.listFiles(dir, predicate: { fileName in
      return (fileName as NSString).pathExtension == "log" &&
        fileName.range(of: self.prefix)?.lowerBound == fileName.startIndex
    })
  }
  
  /**
   * ログファイルを作成する
   *
   * - parameter firstDate: ログ開始日
   * - returns: ファイル名
   */
  fileprivate func createFile(_ firstDate: Int) -> String {
    let fileName = "\(prefix)\(firstDate).log"
    path = (dir as NSString).appendingPathComponent(fileName)
    
    let fm = FileManager.default
    fm.createFile(atPath: path, contents: nil, attributes: nil)
    fileHandle = FileHandle(forWritingAtPath: path)
    
    return fileName
  }
  
  /**
   * 開いているログファイルがあれば閉じる
   */
  fileprivate func closeFile() {
    if let fileHandle = fileHandle {
      fileHandle.synchronizeFile()
      fileHandle.closeFile()
    }
  }
  
  /**
   * 次にローテーションを行う日付を得る
   *
   * - parameter firstDate: ログ開始日
   * - returns: 次にローテーションを行う日付(日付)
   */
  fileprivate func dateForRotation(_ firstDate: Int) -> Int {
    return Date.fromInt(firstDate)!.addingTimeInterval(
      Double(rotationDays) * 24 * 60 * 60.0).dateInt
  }
  
  /**
   * ファイルをローテーションし、保存数を超える古いファイルは削除する
   */
  fileprivate func rotateFile() {
    closeFile()
    let files = listFiles()
    
    let fm = FileManager.default
    if files.count > maxBackups {
      for i in 0 ..< files.count - maxBackups {
        let fileName = files[i]
        let path = (dir as NSString).appendingPathComponent(fileName)
        do {
          try fm.removeItem(atPath: path)
        } catch _ {
        }
      }
    }
    
    _ = createFile(rotationDate)
    rotationDate = dateForRotation(rotationDate)
  }
}
