//
//  MenuScene.swift
//  ForeverMaze
//
//  Created by Zane Claes on 11/22/15.
//  Copyright © 2015 inZania LLC. All rights reserved.
//

import SpriteKit
import PromiseKit
import CocoaLumberjack

class MenuScene: SKScene {
  let gameScene:GameScene = GameScene(size: UIScreen.mainScreen().bounds.size)
  let background = SKSpriteNode(imageNamed: "background")
  let particle = NSKeyedUnarchiver.unarchiveObjectWithFile(NSBundle.mainBundle().pathForResource("snow", ofType: "sks")!) as! SKEmitterNode
  let labelLoading = SKLabelNode(text: I18n.t("menu.loading"))
  let banner = SKSpriteNode(texture: Config.worldAtlas.textureNamed("banner"))
  let labelFM = SKLabelNode(text: "ForeverMaze")
  let buttonResume = MenuButton(title: I18n.t("menu.resume"))
  let buttonLogin = MenuButton(title: I18n.t("menu.login"))
  let buttonAbout = MenuButton(title: I18n.t("menu.about"))
  let buttonScores = MenuButton(title: I18n.t("menu.scores"))
  let buttonLogout = MenuButton(title: I18n.t("menu.logout"))
  let player = LocalPlayer(playerID: nil)
  let depression = Depression()
  
  override func didMoveToView(view: SKView) {
    let objectZ:CGFloat = 1000
    let mid = CGPoint(x: CGRectGetMidX(self.scene!.frame), y: CGRectGetMidY(self.scene!.frame))
    background.position = mid
    background.xScale = max( Config.objectScale, 0.6 )
    background.yScale = max( Config.objectScale, 0.6 )
    background.zPosition = -2
    self.addChild(background)
    
    self.particle.position = CGPointMake(mid.x, CGRectGetMaxY(self.scene!.frame) + 40)
    self.particle.name = "snow"
    self.particle.zPosition = -1
    self.addChild(self.particle)
    
    labelLoading.fontName = Config.font
    labelLoading.fontSize = 24
    labelLoading.color = SKColor.whiteColor()
    labelLoading.position = CGPoint(x: mid.x, y: 10)
    self.addChild(labelLoading)
    
    banner.position = CGPoint(x: mid.x, y: self.scene!.frame.size.height/3*2)
    banner.zPosition = objectZ + 1.0
    addChild(banner)
    
    labelFM.fontName = Config.font
    labelFM.fontSize = 28
    labelFM.color = SKColor.whiteColor()
    labelFM.position = banner.position + CGPointMake(0, -1)
    labelFM.zPosition = objectZ + 2.0
    self.addChild(labelFM)
    
    var lastWasX = false
    let playerPosition = CGPoint(x: self.scene!.frame.size.width/5*4, y: self.scene!.frame.size.height/4)
    var coordinate = Coordinate(xIndex: 0,yIndex: 0)
    for(var i=0; i<30; i++) {
      addTile(coordinate, locked: false, center: playerPosition)
      
      // Add random X/Y tiles?
      if arc4random_uniform(2) == 0 {
        addTile(coordinate + (-1,0), locked: true, center: playerPosition)
      }
      if !lastWasX && arc4random_uniform(2) == 0 {
        addTile(coordinate + (1,0), locked: true, center: playerPosition)
      }
      
      if (arc4random_uniform(3) == 0) {
        coordinate = coordinate + (-1,0)
        lastWasX = true
      }
      else {
        coordinate = coordinate + (0,1)
        lastWasX = false
      }
    }
    
    self.player.direction = Direction.S
    player.draw().then { (gameObject) -> Void in
      self.player.sprite.position = playerPosition
      self.player.sprite.zPosition = objectZ
      self.addChild(self.player.sprite)
    }
    
    self.depression.direction = Direction.E
    depression.draw().then { (gameObject) -> Void in
      self.depression.sprite.position = CGPoint(x: self.scene!.frame.size.width/5, y: playerPosition.y)
      self.addChild(self.depression.sprite)
    }
    
    buttonResume.position = mid
    buttonResume.hidden = true
    buttonResume.zPosition = objectZ
    buttonResume.emotion = Emotion.Anger
    buttonResume.buttonFunc = { (button) -> Void in
      self.pushGameScene()      
    }
    self.addChild(buttonResume)
    
    buttonLogin.position = buttonResume.position
    buttonLogin.hidden = true
    buttonLogin.zPosition = objectZ
    buttonLogin.emotion = Emotion.Anger
    buttonLogin.buttonFunc = { (button) -> Void in
      self.login()
    }
    self.addChild(buttonLogin)
    
    buttonAbout.stack(buttonLogin)
    buttonAbout.hidden = true
    buttonAbout.zPosition = objectZ
    buttonAbout.emotion = Emotion.Fear
    buttonAbout.buttonFunc = { (button) -> Void in
    }
    self.addChild(buttonAbout)
    
    buttonScores.stack(buttonAbout)
    buttonScores.hidden = true
    buttonScores.zPosition = objectZ
    buttonScores.emotion = Emotion.Happiness
    buttonScores.buttonFunc = { (button) -> Void in
    }
    self.addChild(buttonScores)
    
    buttonLogout.stack(buttonScores)
    buttonLogout.hidden = true
    buttonLogout.zPosition = objectZ
    buttonLogout.emotion = Emotion.Sadness
    buttonLogout.buttonFunc = { (button) -> Void in
      Account.logout()
      self.updateUI()
    }
    self.addChild(buttonLogout)

    load()
  }
  
  func addTile(coordinate: Coordinate, locked: Bool, center: CGPoint) -> Tile {
    let tile = Tile(coordinate: coordinate, unlocked: !locked)
    tile.sprite.position = gameScene.coordinateToPosition(coordinate, closeToCenter: true) + center
    tile.sprite.zPosition = gameScene.zPositionForYPosition(tile.sprite.position.y, zIndex: 0)
    tile.loading.then { (obj) -> Void in
      if locked {
        tile.sprite.color = tile.emotion.lockedColor
        tile.icon.hidden = true
        tile.icon.position = CGPointMake(0, tile.icon.frame.size.height/2 - 8)
      }
    }
    addChild(tile.sprite)
    return tile
  }
  
  func load() {
    guard !isLoading && Account.player == nil else {
      updateUI()
      return
    }
    isLoading = true
    DDLogInfo("Loading account...")
    Config.setup().then { () -> Promise<LocalPlayer!> in
      return Account.resume()
    }.then { (player) -> Void in
      DDLogInfo("[PLAYER]: \(player)")
    }.always {
      self.isLoading = false
    }.error { (error) -> Void in
      Errors.show(error as NSError)
      DDLogError("RESUME ERR \(error)")
    }
  }
  
  func updateUI() {
    let canResume = Account.player != nil
    self.buttonLogin.hidden = isLoading || canResume
    self.buttonResume.hidden = isLoading || !canResume
    self.buttonLogout.hidden = self.buttonResume.hidden
    self.buttonAbout.hidden = isLoading
    self.buttonScores.hidden = isLoading
    self.labelLoading.hidden = !isLoading
  }
  
  var isLoading:Bool {
    get {
      return UIApplication.sharedApplication().networkActivityIndicatorVisible
    }
    set {
      UIApplication.sharedApplication().networkActivityIndicatorVisible = newValue
      self.updateUI()
    }
  }

  func pushGameScene() {
    let transition = SKTransition.crossFadeWithDuration(1.5)
    gameScene.scaleMode = SKSceneScaleMode.AspectFill
    self.scene!.view!.presentScene(gameScene, transition: transition)
  }

  func login() {
    guard !isLoading else {
      return
    }
    isLoading = true

    Account.login().then { (playerID) -> Void in
      DDLogInfo("PLAYER ID \(playerID)")
      self.pushGameScene()
    }.always {
      self.isLoading = false
    }.error { (error) -> Void in
      Errors.show(error as NSError)
      DDLogError("LOGIN ERR \(error)")
    }
  }
}
