//
//  AppDelegate.swift
//  ForeverMaze
//
//  Created by Zane Claes on 11/20/15.
//  Copyright © 2015 inZania LLC. All rights reserved.
//

import UIKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

  var window: UIWindow?

  func application(application: UIApplication, didFinishLaunchingWithOptions launchOptions: [NSObject: AnyObject]?) -> Bool {
    return FBSDKApplicationDelegate.sharedInstance().application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func application(application: UIApplication,
    openURL url: NSURL,
    sourceApplication: String?,
    annotation: AnyObject) -> Bool {
      return FBSDKApplicationDelegate.sharedInstance().application(
        application,
        openURL: url,
        sourceApplication: sourceApplication,
        annotation: annotation)
  }
  
  var gameViewController:GameViewController! {
    guard self.window != nil else {
      return nil
    }
    return window!.rootViewController as? GameViewController
  }

  func applicationWillResignActive(application: UIApplication) {
    gameViewController!.showMenu()
  }

  func applicationDidEnterBackground(application: UIApplication) {
    Audio.sharedInstance.pause()
  }

  func applicationWillEnterForeground(application: UIApplication) {
    Audio.sharedInstance.play()
    Config.setup() // Re-setup so that we have latest config, esp. if coming from offline
  }

  func applicationDidBecomeActive(application: UIApplication) {
    FBSDKAppEvents.activateApp()
  }

  func applicationWillTerminate(application: UIApplication) {
  }
}

