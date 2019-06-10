//
//  FileUtil.swift
//  KLibrary
//
//  Created by KO on 2015/01/25.
//  Copyright (c) 2019年 KO. All rights reserved.
//

import Foundation

/**
 * ファイルに関するユティリティ関数を集めたクラス
 */
open class FileUtil {
  /** 
   * テキストファイル全行を得る
   *
   * - parameter path: テキストファイルのパス
   * - returns: 各行の文字列の配列
   */
  open class func readLines(_ path: String) -> [String] {
    let contents = try? String(contentsOfFile: path, encoding: String.Encoding.utf8)
    if let contents = contents {
      let lines = contents.components(separatedBy: "\n")
      return lines
    } else {
      return [String]()
    }
  }
  
  /** iOSアプリのサンドボックスのドキュメントディレクトリ */
  open class var documentDir: String {
    let docDirs = NSSearchPathForDirectoriesInDomains(FileManager.SearchPathDirectory.documentDirectory,
      FileManager.SearchPathDomainMask.userDomainMask, true)
    return docDirs[0] 
  }
  
  /** iOSアプリのサンドボックスのライブラリディレクトリ */
  open class var libraryDir: String {
    let libDirs = NSSearchPathForDirectoriesInDomains(FileManager.SearchPathDirectory.libraryDirectory,
      FileManager.SearchPathDomainMask.userDomainMask, true)
    return libDirs[0]
  }
  
  /**
   * 指定のディレクトリ直下の条件に合致するファイルの一覧を得る
   *
   * - parameter dir: ディレクトリ
   * - parameter predicate: 条件に合致するかどうかを判定する関数
   * - returns: 条件に合致するファイルの一覧
   */
  open class func listFiles(_ dir: String, predicate: (_ fileName: String) -> Bool) -> [String] {
    var result = [String]()
    let fm = FileManager.default
    let files = try? fm.contentsOfDirectory(atPath: dir)
    if let files = files {
      for file in files {
        if predicate(file) {
          result.append(file)
        }
      }
    }
    return result
  }
}
