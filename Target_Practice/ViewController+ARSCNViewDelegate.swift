//
//  ViewController+ARSCNViewDelegate.swift
//  Target_Practice
//
//  Created by Larry Yu on 12/3/23.
//

import ARKit

extension ViewController: ARSCNViewDelegate {
    func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
        self.focusNode.updateFocusNode()
    }
}
