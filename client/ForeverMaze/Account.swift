//
//  Account.swift
//  ForeverMaze
//
//  Created by Zane Claes on 11/20/15.
//  Copyright © 2015 inZania LLC. All rights reserved.
//

import Foundation
import Firebase
import PromiseKit
import CocoaLumberjack

class Account {
  private static let fb: FBSDKLoginManager = FBSDKLoginManager()
  private static let connection = Firebase(url: Config.firebaseUrl)
  static let permissions : Array<String> = ["public_profile", "email", "user_friends"]

  static var player: LocalPlayer?
  static private var auth: FAuthData? = nil
  static var FBID: String!
  static var me:NSDictionary!
  static var allPlayerIDs:[String] = []

  init() {
    NSException(name: "NotImplemented", reason: "Static implementation only.", userInfo: nil).raise()
  }

  static func resume() -> Promise<LocalPlayer!> {
    guard let token: FBSDKAccessToken = FBSDKAccessToken.currentAccessToken() else {
      return Promise { fulfill, reject in fulfill(nil) }
    }
    return self._handOffToken(token)
  }

  static func login() -> Promise<LocalPlayer!> {
    return self._loginToFacebook().then { (token) -> Promise<LocalPlayer!> in
      return self._handOffToken(token)
    }
  }
  
  static private func _loginToFacebook() -> Promise<FBSDKAccessToken> {
    guard let token: FBSDKAccessToken = FBSDKAccessToken.currentAccessToken() else {
      DDLogDebug("[ACCOUNT] Facebook start...")

      return Promise { fulfill, reject in
        Account.fb.logInWithReadPermissions(permissions, fromViewController: nil, handler: { (result, error) -> Void in
          if error != nil {
            reject(error)
          }
          else if result.isCancelled {
            reject(Errors.permissions)
          }
          else if result.grantedPermissions == nil || !result.grantedPermissions.contains("user_friends") {
            reject(Errors.permissions)
          }
          else {
            fulfill(FBSDKAccessToken.currentAccessToken())
          }
        })
      }
    }
    return Promise { fulfill, reject in
      fulfill(token)
    }
  }

  static private func _handOffToken(token: FBSDKAccessToken) -> Promise<LocalPlayer!> {
    DDLogDebug("[ACCOUNT] Firebase start...")
    var player:LocalPlayer!

    return Promise { fulfill, reject in
      self.connection.authWithOAuthProvider("facebook", token: token.tokenString, withCompletionBlock: { (error, auth) -> Void in
        if error == nil && auth?.uid != nil {
          self.auth = auth
          self.FBID = auth?.uid.componentsSeparatedByString(":").last
          fulfill(auth?.uid)
        }
        else {
          reject(error)
        }
      })
    }.then { (playerID) -> Promise<LocalPlayer!> in
      return self._loadPlayer(playerID)
    }.then { (p) -> Promise<NSDictionary> in
      player = p
      return self._loadMe()
    }.then { (me) -> LocalPlayer! in
      self.me = me
      player.alias = self.firstName
      return player
    }
  }
    
  static private func _loadPlayer(playerID: String!) -> Promise<LocalPlayer!> {
    DDLogDebug("[ACCOUNT] Loading player \(playerID)...")
    return LocalPlayer.loadLocalPlayerID(playerID)
  }
  
  /**
   * Uses a global storage of "playerIDs" (all players in the game)
   * First adds the local player to that array, if missing
   * Then builds a local array of playerIDs to load
   */
  static func getOtherPlayers(numPlayers: Int) -> Promise<[String:Player]> {
    var players = Array<Player>()
    
    return Data.loadSnapshot("/playerIDs").then { (snapshot) -> Promise<Void> in
      
      // Make sure the local player is stashed in playerIDs
      self.allPlayerIDs = snapshot == nil ? Array<String>() : snapshot!.value as! Array<String>
      if self.allPlayerIDs.indexOf(self.auth!.uid) == nil {
        self.allPlayerIDs.append(self.auth!.uid)
        let fb = Firebase(url: Config.firebaseUrl + "/playerIDs")
        return fb.write(self.allPlayerIDs)
      }
      else {
        return Promise<Void>()
      }
    }.then { () -> Promise<Void> in
      var playerIDs = Set<String>()
      var pool = self.allPlayerIDs.shuffle()
      
      let meIdx = pool.indexOf(self.auth!.uid)
      if meIdx != nil {
        pool.removeAtIndex(meIdx!)
      }
      
      // Add friends to the player IDs
      let friends = self.facebookFriends.shuffle()
      for friendData in friends {
        let fbid = friendData["id"] as! String
        let friendID = "facebook:\(fbid)"
        let idx = pool.indexOf(friendID)
        if idx != nil {
          playerIDs.insert(friendID)
          pool.removeAtIndex(idx!)
        }
        if playerIDs.count >= numPlayers * 2 {
          break
        }
      }
      DDLogInfo("Friends: \(playerIDs)")
      
      // Backfill with random player IDs (shuffled above)
      while playerIDs.count < numPlayers * 2 && pool.count > 0 {
        playerIDs.insert(pool.first!)
        pool.removeAtIndex(0)
      }
      
      // Create an array of players
      var promises = Array<Promise<Void>>()
      for playerID in playerIDs {
        let player = Player(playerID: playerID)
        promises.append(player.loading.then { (snapshot) -> Void in
          players.append(player)
        })
      }
      
      return when(promises)
    }.then { () -> [String:Player] in
      var filteredPlayers:[String:Player] = [:]
      for player in players {
        let dist = Account.player!.coordinate.getDistance(player.coordinate)
        if dist > Config.minOtherPlayerSpawnDistance {
          filteredPlayers[player.id] = player
        }
      }
      DDLogInfo("All Other Players: \(filteredPlayers)")
      return filteredPlayers
    }
  }
  
  /**
   * Load `me` from Facebook
   * Will include email, name, etc.
   */
  static private func _loadMe() -> Promise<NSDictionary> {
    let params = [ "fields": "id,name,friends,email,installed,first_name,link" ]
    let friendsRequest = FBSDKGraphRequest(graphPath: "me", parameters: params)
    let (loading, fulfill, reject) = Promise<NSDictionary>.pendingPromise()
    friendsRequest.startWithCompletionHandler { (connection, result, error) -> Void in
      guard error == nil else {
        reject(error)
        return
      }
      let data = result as! NSDictionary
      fulfill(data)
    }
    return loading
  }

  static func logout() {
    DDLogDebug("[ACCOUNT] Logged out.")
    self.auth = nil
    self.player = nil
    Account.fb.logOut()
  }
  
  static var facebookFriends:[NSDictionary] {
    let friendsData = self.me["friends"] as! NSDictionary
    return friendsData["data"] as! [NSDictionary]
  }
  
  static var firstName:String {
    return self.me["first_name"] as! String
  }
  
  static var isLoggedIn:Bool {
    return self.auth != nil
  }

  static var playerID:String {
    return (self.auth?.uid)!
  }
}