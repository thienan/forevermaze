//
//  Level.swift
//  ForeverMaze
//
//  Created by Zane Claes on 1/12/16.
//  Copyright © 2016 inZania LLC. All rights reserved.
//

import Foundation
import Firebase

class Level : NSObject {
  let snapshot:FDataSnapshot!
  let levelNumber:UInt
  var depressionSpeedMultiplier:Double = 0.1
  var depressionSpawnDistance:Int = 20
  var depressionSpawnAfterTiles:Int = 10
  var numOtherPlayers:Int = 8
  var numWishingWells:Int = 5
  var emojiMultiplier:Float = 1.0

  init(snapshot: FDataSnapshot!, number: UInt) {
    self.snapshot = snapshot
    self.levelNumber = number
    super.init()
    self.depressionSpeedMultiplier = getValue("depressionSpeedMultiplier") as! Double
    self.depressionSpawnDistance = getValue("depressionSpawnDistance") as! Int
    self.depressionSpawnAfterTiles = getValue("depressionSpawnAfterTiles") as! Int
    self.numOtherPlayers = getValue("numOtherPlayers") as! Int
    self.numWishingWells = getValue("numWishingWells") as! Int
    self.emojiMultiplier = getValue("emojiMultiplier") as! Float
  }
  
  var previousLevel:Level {
    let prev = Int(self.levelNumber) - 1
    return Config.levels[max(0,prev)]
  }
  
  func getValue(key: String) -> AnyObject {
    let value = snapshot.configValue(key)
    guard value != nil else {
      if self.levelNumber == 0 {
        return self.valueForKey("\(key)")!
      }
      else {
        return previousLevel.getValue(key)
      }
    }
    return value!
  }
}
