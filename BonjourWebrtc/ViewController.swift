//
//  ViewController.swift
//  BonjourWebrtc
//
//  Created by Mahabali on 5/4/16.
//  Copyright © 2016 Mahabali. All rights reserved.
//

import UIKit
enum ResponseValue: String {
  case incomingCall = "incomingCall"
  case callAccepted = "callAccepted"
  case callRejected = "callRejected"
}
class ViewController: UIViewController,UITableViewDelegate, UITableViewDataSource {
  @IBOutlet weak var connectionsLabel: UILabel!
  @IBOutlet weak var tableView: UITableView!
  // Differentiates caller and receiver
  var isInitiator = false
  var peerListArray : [String] = []
  let bonjourService = BonjourServiceManager.sharedBonjourServiceManager
  
  override func viewDidLoad() {
    super.viewDidLoad()
    bonjourService.delegate = self
    tableView.register(UITableViewCell.self,
                            forCellReuseIdentifier: "Cell")
    self.title = "Peers"
  }
  
  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    bonjourService.delegate = self
  }
  
  override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
    let unownedSelf = self
    if segue.destination is RTCVideoChatViewController{
      let destinationController:RTCVideoChatViewController = segue.destination as! RTCVideoChatViewController
      destinationController.isInitiator = unownedSelf.isInitiator
      BonjourServiceManager.sharedBonjourServiceManager.delegate = nil
    }
  }
  
  func showAlert(_ caller : String) {
    let unownedSelf = self
    let alert = UIAlertController(title: "Incoming Call",
                                  message: caller,
                                  preferredStyle: .alert)
    let idx = peerListArray.index(of: caller) //
    let acceptAction = UIAlertAction(title: "Accept",
                                     style: .default,
                                     handler: { (action:UIAlertAction) -> Void in
                                      unownedSelf.bonjourService.callRequest("callAccepted", index: idx!)
                                      unownedSelf.isInitiator = false
                                      unownedSelf.startCallViewController()
    })
    let rejectAction = UIAlertAction(title: "Reject",
                                     style: .default) { (action: UIAlertAction) -> Void in
                                      unownedSelf.bonjourService.callRequest("callRejected", index: idx!)
                                      
    }
    alert.addAction(acceptAction)
    alert.addAction(rejectAction)
    present(alert, animated: true)
  }
  
  func startCallViewController(){
    let unownedSelf = self
    DispatchQueue.main.async {
      unownedSelf.performSegue(withIdentifier: "showVideoCall", sender: unownedSelf)
    }
  }
  
  // tableView
  
  func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
    return 70
  }
  
  
  func tableView(_ tableView: UITableView,
                 numberOfRowsInSection section: Int) -> Int {
    return peerListArray.count
  }
  
  func tableView(_ tableView: UITableView,cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    let cell = tableView.dequeueReusableCell(withIdentifier: "Cell")
    cell?.textLabel?.text = peerListArray[indexPath.row]
    return cell!
  }
  
  func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    bonjourService.callRequest("incomingCall", index: indexPath.row)
    self.isInitiator = true
  }
  
  
}

extension ViewController : BonjourServiceManagerProtocol {
  
  func connectedDevicesChanged(_ manager: BonjourServiceManager, connectedDevices: [String]) {
    let unownedSelf = self
    OperationQueue.main.addOperation {
      unownedSelf.connectionsLabel.text = "Connections: \(connectedDevices)"
      unownedSelf.peerListArray = connectedDevices
      unownedSelf.tableView.reloadData()
    }
  }
  
  func receivedData(_ manager: BonjourServiceManager, peerID: String, responseString: String) {
    let unownedSelf = self
    DispatchQueue.main.async {
      switch responseString {
      case ResponseValue.incomingCall.rawValue :
        print("incomingCall")
        unownedSelf.showAlert(peerID)
      case ResponseValue.callAccepted.rawValue:
        print("callAccepted")
        unownedSelf.startCallViewController()
      case ResponseValue.callRejected.rawValue:
        print("callRejected")
      default:
        print("Unknown color value received: \(responseString)")
      }
    }
  }
}
