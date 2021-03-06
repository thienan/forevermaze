//
//  Errors.swift
//  ForeverMaze
//
//  Created by Zane Claes on 11/23/15.
//  Copyright © 2015 inZania LLC. All rights reserved.
//

import Foundation
import ReachabilitySwift

class Errors {
  
  static let messages = [
    Config.baseErrorDomain! + ".permissions" : I18n.t("errors.permissions"),
    Config.baseErrorDomain! + ".network" : I18n.t("errors.network"),
    Config.baseErrorDomain! + ".data" : I18n.t("errors.data"),
  ]
  
  static func show(err: NSError) {
    let error = transformError(err)
    let title = messages[error.domain] != nil ? messages[error.domain] : error.localizedDescription
    Analytics.log(.Error, params: ["title": title==nil ? "?" : title!, "desc": error.description])
    UIAlertView(title: title!, message: nil, delegate: nil, cancelButtonTitle: I18n.t("menu.ok")).show()
  }

  static let network = NSError(
    domain: Config.baseErrorDomain! + ".network",
    code: 1,
    userInfo: [NSLocalizedDescriptionKey : I18n.t("errors.network")]
  )

  static let data = NSError(
    domain: Config.baseErrorDomain! + ".data",
    code: 2,
    userInfo: [NSLocalizedDescriptionKey : I18n.t("errors.data")]
  )
  
  static let permissions = NSError(
    domain: Config.baseErrorDomain! + ".permissions",
    code: 3,
    userInfo: [NSLocalizedDescriptionKey : I18n.t("errors.permissions")]
  )
  
  static func transformError(originalError: NSError) -> NSError {
    if originalError.domain == "FirebaseAuthentication" {
      if originalError.code == -15 {// Network / Auth error
        return Errors.network
      }
    }
    return originalError
  }
}
