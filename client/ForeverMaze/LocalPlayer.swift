//
//  LocalPlayer.swift
//  ForeverMaze
//
//  Created by Zane Claes on 11/20/15.
//  Copyright © 2015 inZania LLC. All rights reserved.
//

import Foundation
import PromiseKit
import Firebase
import CocoaLumberjack
import SpriteKit

class LocalPlayer : Player {

  var adjacentPositions:[String: Emotion] = [:]

  override init(playerID: String!) {
    super.init(playerID: playerID)
    self.connection.childByAppendingPath("online").onDisconnectSetValue(false);
  }

  static func loadLocalPlayerID(playerID: String!) -> Promise<LocalPlayer!> {
    guard (playerID != nil) else {
      return Promise { fulfill, reject in fulfill(nil) }
    }
    let player = LocalPlayer(playerID: playerID)
    return player.loading.then { (snapshot) -> Promise<GameObject!> in
      Account.player = player
      player.lastLogin = NSDate().timeIntervalSince1970
      player.online = true
      return player.draw()
    }.then { (gameObject) -> LocalPlayer! in
      return Account.player
    }
  }

  /**
   * After logging in, rebuild the counts for unlocked tiles
   * and create a hash of valid positions
   */
  func setupUnlockedTiles() -> Promise<Void> {
    var promises = Array<Promise<Void>>(arrayLiteral: Promise<Void>())
    var sadness = 0, happiness = 0, anger = 0, fear = 0
    self.adjacentPositions = [:]
    for path in self.unlockedTiles {
      let coordinate = Coordinate(desc: path)
      let promise = Data.loadSnapshot("/tiles/\(coordinate.description)").then { (snapshot) -> Void in
        guard snapshot != nil else {
          return
        }
        let emotion = Emotion(rawValue: (snapshot!.childSnapshotForPath("e").value.integerValue)!)
        if emotion == .Anger {
          anger++
        }
        else if emotion == .Happiness {
          happiness++
        }
        else if emotion == .Sadness {
          sadness++
        }
        else if emotion == .Fear {
          fear++
        }
      }
      promises.append(promise)
      promises.append(self.addUnlockedAdjacentCoordinates(coordinate))
    }
    return when(promises).then { () -> Void in
      self.numSadness = sadness
      self.numHappiness = happiness
      self.numAnger = anger
      self.numFear = fear
    }
  }

  var numUnlockedTiles:Int {
    return numSadness + numHappiness + numAnger + numFear
  }

  /**
   * We can unlock an emotion if:
   * 1) It is the least-unlocked emotion
   * 2) It is less common than its opposite
   */
  func canUnlockEmotion(emotion: Emotion) -> Bool {
    let minVal = min(self.numAnger, min(self.numFear, min(self.numHappiness, self.numSadness)))
    var count = 0
    //var opposite = 0
    if emotion == .Anger {
      count = self.numAnger
      //opposite = self.numFear
    }
    else if emotion == .Sadness {
      count = self.numSadness
      //opposite = self.numHappiness
    }
    else if emotion == .Fear {
      count = self.numFear
      //opposite = self.numAnger
    }
    else if emotion == .Happiness {
      count = self.numHappiness
      //opposite = self.numSadness
    }
    return count < 3 || count == minVal //|| count <= opposite
  }
  
  func canUnlockTile(tile: Tile) -> Bool {
    guard self.adjacentPositions[tile.coordinate.description] != nil else {
      return false
    }
    guard self.numValidMoves > 0 else {
      return true
    }
    return self.canUnlockEmotion(tile.emotion)
  }

  /**
   * Counts the valid moves
   */
  func numValidMovesForEmotion(emotion: Emotion) -> Int {
    guard self.canUnlockEmotion(emotion) else {
      return 0
    }
    var ret = 0
    for (_, tileEmotion) in self.adjacentPositions {
      if tileEmotion == emotion {
        ret++
      }
    }
    return ret
  }
  
  var numValidMoves:Int {
    var ret = 0
    for (_, emotion) in self.adjacentPositions {
      if self.canUnlockEmotion(emotion) {
        ret++
      }
    }
    return ret
  }

  /**
   * Take all the locked tiles adjacent to a position and add them to self.adjacentPositions
   */
  func addUnlockedAdjacentCoordinates(coordinate: Coordinate) -> Promise<Void> {
    var promises = Array<Promise<Void>>(arrayLiteral: Promise<Void>())
    for direction in Direction.directions {
      let otherPosition = coordinate + direction.amount
      if !self.hasUnlockedTileAt(otherPosition) && self.adjacentPositions[otherPosition.description] == nil {
        let tile = self.gameScene?.tiles[otherPosition.description]
        if tile != nil {
          self.adjacentPositions[otherPosition.description] = tile?.emotion
        }
        else {
          let promise = Data.loadSnapshot("/tiles/\(otherPosition.description)").then { (snapshot) -> Void in
            let emotion = Emotion(rawValue: (snapshot!.childSnapshotForPath("e").value.integerValue)!)
            self.adjacentPositions[otherPosition.description] = emotion
          }
          promises.append(promise)
        }
      }
    }
    return when(promises)
  }
  /**
   *
   */
  func updateAdjacentTilesLockedStates() {
    for adjacentTile in self.gameScene!.tiles.values {
      if self.adjacentPositions[adjacentTile.coordinate.description] != nil {
        adjacentTile.updateLockedState()
      }
    }
  }

  func unlockTile(tile: Tile) -> Bool {
    guard self.unlockedTiles.indexOf(tile.coordinate.description) == nil else {
      return false
    }
    if tile.emotion == .Anger {
      self.numAnger++
    }
    else if tile.emotion == .Sadness {
      self.numSadness++
    }
    else if tile.emotion == .Fear {
      self.numFear++
    }
    else if tile.emotion == .Happiness {
      self.numHappiness++
    }
    self.unlockedTiles.append(tile.coordinate.description)
    tile.updateLockedState()
    self.adjacentPositions.removeValueForKey(tile.coordinate.description)
    self.addUnlockedAdjacentCoordinates(tile.coordinate).then { () -> () in
      self.updateAdjacentTilesLockedStates()
    }
    
    let squash = SKAction.scaleXTo(self.sprite.xScale, y: 0.66, duration: 0.05)
    let expand = SKAction.scaleXTo(self.sprite.xScale, y: 1, duration: 0.05)
    let jump = SKAction.moveByX(0, y: 20, duration: 0.15)
    let emoji = SKAction.runBlock { () -> Void in
      self.emoji = self.emoji + 1
      self.gameScene!.layerUI.runEmojiAnimation(tile.emotion)
      self.gameScene!.layerUI.updateUI()
      tile.playUnlockAnimation()
    }
    let fall = SKAction.moveByX(0, y: -20, duration: 0.15)
    self.sprite.runAction(SKAction.sequence([squash, expand, jump, emoji, fall]), withKey: Animation.unlockKey)
    
    return true
  }
}