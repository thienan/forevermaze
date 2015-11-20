//
//  Depression.swift
//  ForeverMaze
//
//  Created by Zane Claes on 1/9/16.
//  Copyright © 2016 inZania LLC. All rights reserved.
//

import Foundation
import SpriteKit

class Depression : Mobile {
  let particle = NSKeyedUnarchiver.unarchiveObjectWithFile(NSBundle.mainBundle().pathForResource("depression", ofType: "sks")!) as! SKEmitterNode

  init () {
    super.init(firebasePath: nil)
    alias = I18n.t("Depression")
    self.draw()
  }
  
  override var assetName:String {
    return "depression"
  }
  
  override func updateAnimation() {
    if self.sprite.scene != nil && self.particle.scene == nil {
      self.particle.position = CGPointMake(0, self.sprite.frame.size.height/3)
      self.particle.name = "smoke"
      self.particle.zPosition = -1
      self.particle.targetNode = self.sprite.scene
      self.sprite.addChild(self.particle)
    }
    super.updateAnimation()
    self.particle.xScale = self.sprite.xScale
  }

  override func step() {
    super.step(self.coordinate.getDirection(Account.player!.coordinate))
    Account.player!.depressionPos = self.coordinate.description
  }
  
  override var speed:Double {
    guard Account.player != nil else {
      return 1
    }
    return Account.player!.level.depressionSpeedMultiplier
  }
}