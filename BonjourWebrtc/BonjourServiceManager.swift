//
//  BonjourServiceManager.swift
//  ConnectedColors
//
//  Created by Ralf Ebert on 28/04/15.
//  Copyright (c) 2015 Ralf Ebert. All rights reserved.
//

import Foundation
import MultipeerConnectivity

protocol BonjourServiceManagerProtocol {
  func connectedDevicesChanged(_ manager : BonjourServiceManager, connectedDevices: [String])
  func receivedData(_ manager : BonjourServiceManager, peerID : String, responseString: String)
}

class BonjourServiceManager : NSObject {
  static let sharedBonjourServiceManager = BonjourServiceManager()
  private let serviceType = "webrtc-service"
  private let myPeerId = MCPeerID(displayName: UIDevice.current.name)
  private let serviceAdvertiser : MCNearbyServiceAdvertiser
  private let serviceBrowser : MCNearbyServiceBrowser
  var selectedPeer:MCPeerID?
  var delegate : BonjourServiceManagerProtocol?
  
  override init() {
    self.serviceAdvertiser = MCNearbyServiceAdvertiser(peer: myPeerId, discoveryInfo: nil, serviceType: serviceType)
    self.serviceBrowser = MCNearbyServiceBrowser(peer: myPeerId, serviceType: serviceType)
    super.init()
    self.serviceAdvertiser.delegate = self
    self.serviceAdvertiser.startAdvertisingPeer()
    self.serviceBrowser.delegate = self
    self.serviceBrowser.startBrowsingForPeers()
  }
  
  deinit {
    self.serviceAdvertiser.stopAdvertisingPeer()
    self.serviceBrowser.stopBrowsingForPeers()
  }
  
  lazy var session: MCSession = {
    let session = MCSession(peer: self.myPeerId, securityIdentity: nil, encryptionPreference: .required)
    session.delegate = self
    return session
  }()
  
  
  
  func sendColor(_ colorName : String) {
    print("sendColor: \(colorName)")
    if session.connectedPeers.count > 0 {
      do {
        try self.session.send(Data(colorName.utf8), toPeers: session.connectedPeers, with: .reliable)
      } catch {
        print("Error \(error)")
      }
    }
  }
  
  
  func callRequest(_ recipient : String, index : NSInteger) {
    
    if session.connectedPeers.count > 0 {
      do {
        try self.session.send(Data(recipient.utf8), toPeers: [session.connectedPeers[index]], with: .reliable)
        self.selectedPeer = session.connectedPeers[index]
        print("connected peers --- > \(session.connectedPeers[index])")
      } catch {
        print(error)
      }
    }
    
  }
  
  func sendDataToSelectedPeer(_ json:Dictionary<String,Any>){
    do {
      let jsonData = try JSONSerialization.data(withJSONObject: json, options: .prettyPrinted)
      try self.session.send(jsonData, toPeers: [self.selectedPeer!], with: .reliable)
      print("command \(json) --- > \(selectedPeer!.displayName)")
    } catch {
      print("\(error)")
    }
  }
  
  
  
}

extension BonjourServiceManager : MCNearbyServiceAdvertiserDelegate {

  func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didNotStartAdvertisingPeer error: Error) {
    print("didNotStartAdvertisingPeer: \(error)")
  }

  func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID, withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) {
    print("didReceiveInvitationFromPeer \(peerID)")
    invitationHandler(true, self.session)
  }
  
}

extension BonjourServiceManager : MCNearbyServiceBrowserDelegate {
  
  func browser(_ browser: MCNearbyServiceBrowser, didNotStartBrowsingForPeers error: Error) {
    print("didNotStartBrowsingForPeers: \(error)")
  }
  
  func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String : String]?) {
    print("foundPeer: \(peerID)")
    print("invitePeer: \(peerID)")
    browser.invitePeer(peerID, to: self.session, withContext: nil, timeout: 10)
  }
  
  func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
    print("lostPeer: \(peerID)")
  }
  
}

extension MCSessionState {
  
  func stringValue() -> String {
    switch(self) {
    case .notConnected: return "NotConnected"
    case .connecting: return "Connecting"
    case .connected: return "Connected"
    }
  }
  
}

extension BonjourServiceManager : MCSessionDelegate {
  
  func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
    print("peer \(peerID) didChangeState: \(state.stringValue())")
    self.delegate?.connectedDevicesChanged(self, connectedDevices: session.connectedPeers.map({$0.displayName}))
    print(session.connectedPeers.map({$0.displayName}))
    var arr:[String] = session.connectedPeers.map({$0.displayName})
    if arr.count > 0 {
      print(arr[0])
    }
    
  }
  
  func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
    let str = String(decoding: data, as: UTF8.self)
    print("didReceiveData: \(str) from \(peerID.displayName) bytes")
    let peerId = peerID.displayName
    self.delegate?.receivedData(self, peerID: peerId, responseString: str)
  }
  
  func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {
    print("didReceiveStream")
  }
  
  func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {
    print("didFinishReceivingResourceWithName")
  }
  
  func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {
    print("didStartReceivingResourceWithName")
  }
  
}
