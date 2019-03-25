//
//  RTCVideoChatViewController.swift
//  Apprtc
//
//  Created by Mahabali on 9/6/15.
//  Copyright (c) 2015 Mahabali. All rights reserved.
//

import UIKit
import AVFoundation
class RTCVideoChatViewController: UIViewController,RTCEAGLVideoViewDelegate,WebrtcManagerProtocol,BonjourServiceManagerProtocol {
  //Views, Labels, and Buttons
  @IBOutlet weak var remoteView:RTCEAGLVideoView?
  @IBOutlet weak var localView:RTCEAGLVideoView?
  @IBOutlet weak var footerView:UIView?
  @IBOutlet weak var buttonContainerView:UIView?
  @IBOutlet weak var audioButton:UIButton?
  @IBOutlet weak var videoButton:UIButton?
  @IBOutlet weak var hangupButton:UIButton?
  //Auto Layout Constraints used for animations
  @IBOutlet weak var remoteViewTopConstraint:NSLayoutConstraint?
  @IBOutlet weak var remoteViewRightConstraint:NSLayoutConstraint?
  @IBOutlet weak var remoteViewLeftConstraint:NSLayoutConstraint?
  @IBOutlet weak var remoteViewBottomConstraint:NSLayoutConstraint?
  @IBOutlet weak var localViewWidthConstraint:NSLayoutConstraint?
  @IBOutlet weak var localViewHeightConstraint:NSLayoutConstraint?
  @IBOutlet weak var  localViewRightConstraint:NSLayoutConstraint?
  @IBOutlet weak var  localViewBottomConstraint:NSLayoutConstraint?
  @IBOutlet weak var  footerViewBottomConstraint:NSLayoutConstraint?
  @IBOutlet weak var  buttonContainerViewLeftConstraint:NSLayoutConstraint?
  var   roomUrl:NSString?;
  var   _roomName:NSString=NSString(format: "")
  var   roomName:NSString?
  var   localVideoTrack:RTCVideoTrack?;
  var   remoteVideoTrack:RTCVideoTrack?;
  var   localVideoSize:CGSize?;
  var   remoteVideoSize:CGSize?;
  var   isZoom:Bool = false; //used for double tap remote view
  let   bonjourServiceManager = BonjourServiceManager.sharedBonjourServiceManager
  let   webrtcManager = WebrtcManager()
  var isInitiator = false;
  
  override func viewDidLoad() {
    super.viewDidLoad()
    BonjourServiceManager.sharedBonjourServiceManager.delegate = self
    webrtcManager.delegate = self
    webrtcManager.initiator = self.isInitiator
    webrtcManager.startWebrtcConnection()
    self.isZoom = false;
    self.audioButton?.layer.cornerRadius=20.0
    self.videoButton?.layer.cornerRadius=20.0
    self.hangupButton?.layer.cornerRadius=20.0
    let tapGestureRecognizer:UITapGestureRecognizer=UITapGestureRecognizer(target: self, action:#selector(RTCVideoChatViewController.toggleButtonContainer) )
    tapGestureRecognizer.numberOfTapsRequired=1
    self.view.addGestureRecognizer(tapGestureRecognizer)
    let zoomGestureRecognizer:UITapGestureRecognizer=UITapGestureRecognizer(target: self, action:#selector(RTCVideoChatViewController.zoomRemote) )
    zoomGestureRecognizer.numberOfTapsRequired=2
    self.view.addGestureRecognizer(zoomGestureRecognizer)
    self.remoteView?.delegate=self
    self.localView?.delegate=self
    NotificationCenter.default.addObserver(self, selector: #selector(RTCVideoChatViewController.orientationChanged(_:)), name: UIDevice.orientationDidChangeNotification, object: nil)
    // Do any additional setup after loading the view.

  }
  
  override func viewWillAppear(_ animated: Bool) {
    self.navigationController?.setNavigationBarHidden(true, animated: true)
    self.localViewBottomConstraint?.constant=0.0
    self.localViewRightConstraint?.constant=0.0
    self.localViewHeightConstraint?.constant=self.view.frame.size.height
    self.localViewWidthConstraint?.constant=self.view.frame.size.width
    self.footerViewBottomConstraint?.constant=0.0
  }
  
  override func  viewWillDisappear(_ animated: Bool) {
    self.navigationController?.setNavigationBarHidden(false, animated: false)
    NotificationCenter.default.removeObserver(self)
  }
  
  override var shouldAutorotate: Bool {
    return true
  }
  
  override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
    return .allButUpsideDown
  }
  
  func applicationWillResignActive(application:UIApplication){
    self.disconnect()
  }
  
  @objc func orientationChanged(_ notification:NSNotification){
    if let _ = self.localVideoSize {
      self.videoView(self.localView!, didChangeVideoSize: self.localVideoSize!)
    }
    if let _ = self.remoteVideoSize {
      self.videoView(self.remoteView!, didChangeVideoSize: self.remoteVideoSize!)
    }
  }
  override var prefersStatusBarHidden: Bool {
    return true
  }
  
  override func didReceiveMemoryWarning() {
    super.didReceiveMemoryWarning()
    // Dispose of any resources that can be recreated.
  }
  
  @IBAction func audioButtonPressed (_ sender:UIButton){
    sender.isSelected = !sender.isSelected

  }
  @IBAction func videoButtonPressed(_ sender:UIButton){
    sender.isSelected = !sender.isSelected
 
  }
  
  @IBAction func hangupButtonPressed(_ sender:UIButton){
    self.sendDisconnectToPeer()
    self.disconnect()
    self.navigationController?.popToRootViewController(animated: true)
  }
  
  func disconnect(){
    self.localVideoTrack?.remove(self.localView)
    self.remoteVideoTrack?.remove(self.remoteView)
    self.localView?.renderFrame(nil)
    self.remoteView?.renderFrame(nil)
    self.localVideoTrack=nil
    self.remoteVideoTrack=nil
    self.webrtcManager.disconnect()
  }
  
  func remoteDisconnected(){
    self.remoteVideoTrack?.remove(self.remoteView)
    self.remoteView?.renderFrame(nil)
    if self.localVideoSize != nil {
      self.videoView(self.localView!, didChangeVideoSize: self.localVideoSize!)
    }
  }
  
  @objc func toggleButtonContainer() {
    UIView.animate(withDuration: 0.3, animations: { () -> Void in
      if (self.buttonContainerViewLeftConstraint!.constant <= -40.0) {
        self.buttonContainerViewLeftConstraint!.constant=20.0
        self.buttonContainerView!.alpha=1.0;
      }
      else {
        self.buttonContainerViewLeftConstraint!.constant = -40.0;
        self.buttonContainerView!.alpha=0.0;
      }
      self.view.layoutIfNeeded();
    })
  }
  
  @objc func zoomRemote() {
    //Toggle Aspect Fill or Fit
    self.isZoom = !self.isZoom;
    self.videoView(self.remoteView!, didChangeVideoSize: self.remoteVideoSize!)
  }
  

  func localStreamAvailable(_ stream: RTCMediaStream) {

    DispatchQueue.main.async {
    let localVideoTrack = stream.videoTracks[0]
    self.localVideoTrack?.remove(self.localView)
    self.localView?.renderFrame(nil)
    self.localVideoTrack=localVideoTrack as? RTCVideoTrack
    self.localVideoTrack?.add(self.localView)
    }
  }
 
  func remoteStreamAvailable(_ stream: RTCMediaStream) {
    DispatchQueue.main.async {
    let remoteVideoTrack = stream.videoTracks[0]
      DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(2)) {
      let audioSession:AVAudioSession = AVAudioSession.sharedInstance()
      do{
        try audioSession.overrideOutputAudioPort(.speaker)
      }
      catch{
        print("Audio Port Error");
      }
    }
    self.remoteVideoTrack=remoteVideoTrack as? RTCVideoTrack
    self.remoteVideoTrack?.add(self.remoteView)
    UIView.animate(withDuration: 0.4, animations: {
      self.localViewBottomConstraint?.constant=28.0
      self.localViewRightConstraint?.constant=28.0
      self.localViewHeightConstraint?.constant=self.view.frame.size.height/4
      self.localViewWidthConstraint?.constant=self.view.frame.size.width/4
      self.footerViewBottomConstraint?.constant = -80.0
    })
    }
  }

  func updateUIForRotation(){
    let statusBarOrientation:UIInterfaceOrientation = UIApplication.shared.statusBarOrientation;
    let deviceOrientation:UIDeviceOrientation  = UIDevice.current.orientation
    if (statusBarOrientation.rawValue==deviceOrientation.rawValue){
      if let  _ = self.localVideoSize {
      self.videoView(self.localView!, didChangeVideoSize: self.localVideoSize!)
      }
      if let _ = self.remoteVideoSize {
        self.videoView(self.remoteView!, didChangeVideoSize: self.remoteVideoSize!)
      }
    }
    else{
      print("Unknown orientation Skipped rotation");
    }
  }
  
  func videoView(_ videoView: RTCEAGLVideoView, didChangeVideoSize size: CGSize) {
    DispatchQueue.main.async {
    let orientation: UIInterfaceOrientation = UIApplication.shared.statusBarOrientation
    UIView.animate(withDuration: 0.4, animations: { () -> Void in
      let containerWidth: CGFloat = self.view.frame.size.width
      let containerHeight: CGFloat = self.view.frame.size.height
      let defaultAspectRatio: CGSize = CGSize(width: 4, height: 3)
      if videoView == self.localView {
        self.localVideoSize = size
        let aspectRatio: CGSize = size == .zero ? defaultAspectRatio : size
        var videoRect: CGRect = self.view.bounds
        if (self.remoteVideoTrack != nil) {
          videoRect = CGRect(x: 0.0, y: 0.0, width: self.view.frame.size.width / 4.0, height: self.view.frame.size.height / 4.0)
          if orientation == .landscapeLeft || orientation == .landscapeRight {
            videoRect = CGRect(x: 0.0, y: 0.0, width: self.view.frame.size.height / 4.0, height: self.view.frame.size.width / 4.0)
          }
        }
        let videoFrame: CGRect = AVMakeRect(aspectRatio: aspectRatio, insideRect: videoRect)
        self.localViewWidthConstraint!.constant = videoFrame.size.width
        self.localViewHeightConstraint!.constant = videoFrame.size.height
        if (self.remoteVideoTrack != nil) {
          self.localViewBottomConstraint!.constant = 28.0
          self.localViewRightConstraint!.constant = 28.0
        }
        else{
          self.localViewBottomConstraint!.constant = containerHeight/2.0 - videoFrame.size.height/2.0
          self.localViewRightConstraint!.constant = containerWidth/2.0 - videoFrame.size.width/2.0
        }
      }
      else if videoView == self.remoteView {
        self.remoteVideoSize = size
        let aspectRatio: CGSize = size == .zero ? defaultAspectRatio : size
        let videoRect: CGRect = self.view.bounds
        var videoFrame: CGRect = AVMakeRect(aspectRatio: aspectRatio, insideRect: videoRect)
        if self.isZoom {
          let scale: CGFloat = max(containerWidth / videoFrame.size.width, containerHeight / videoFrame.size.height)
          videoFrame.size.width *= scale
          videoFrame.size.height *= scale
        }
        self.remoteViewTopConstraint!.constant = (containerHeight / 2.0 - videoFrame.size.height / 2.0)
        self.remoteViewBottomConstraint!.constant = (containerHeight / 2.0 - videoFrame.size.height / 2.0)
        self.remoteViewLeftConstraint!.constant = (containerWidth / 2.0 - videoFrame.size.width / 2.0)
        self.remoteViewRightConstraint!.constant = (containerWidth / 2.0 - videoFrame.size.width / 2.0)
      }
      self.view.layoutIfNeeded()
    })
    }
  }
  func offerSDPCreated(_ sdp:RTCSessionDescription){
    let json: [String: Any] = ["offerSDP":sdp.jsonDictionary()]
    bonjourServiceManager.sendDataToSelectedPeer(json)
  }
  func answerSDPCreated(_ sdp:RTCSessionDescription){
    let json: [String: Any] = ["answerSDP":sdp.jsonDictionary()]
    bonjourServiceManager.sendDataToSelectedPeer(json)
  
  }
  func iceCandidatesCreated(_ iceCandidate:RTCICECandidate){
    let json: [String: Any] = ["iceCandidate":iceCandidate.jsonDictionary()]
    bonjourServiceManager.sendDataToSelectedPeer(json)
  }
  
  func sendDisconnectToPeer(){
    let json: [String: Any] = ["disconnect":"disconnect"]
    bonjourServiceManager.sendDataToSelectedPeer(json)
  }
  
  func connectedDevicesChanged(_ manager : BonjourServiceManager, connectedDevices: [String]){
    
  }
  func receivedData(_ manager : BonjourServiceManager, peerID : String, responseString: String){
    let dictionary = convertStringToDictionary(responseString)
    let keyValue = dictionary?.keys.first
    if keyValue! == "offerSDP"{
      let description = dictionary!["offerSDP"] as! [String:AnyObject]
      let offerSDP = RTCSessionDescription.init(fromJSONDictionary: description )
      self.webrtcManager.remoteSDP = offerSDP
      self.webrtcManager.createAnswer()
    }
    else if keyValue! == "answerSDP"{
      let description = dictionary!["answerSDP"] as! [String:AnyObject]
      let offerSDP = RTCSessionDescription.init(fromJSONDictionary: description )
      self.webrtcManager.remoteSDP = offerSDP
      self.webrtcManager.setAnswerSDP()
    }
    
    else if keyValue! == "iceCandidate"{
      
      let description = dictionary!["iceCandidate"] as! [String:AnyObject]
      let iceCandidate = RTCICECandidate.init(fromJSONDictionary: description)
      self.webrtcManager.setICECandidates(iceCandidate!)
    }
    else if keyValue! == "disconnect"{
      DispatchQueue.main.async {
        self.hangupButtonPressed(self.hangupButton!)
      }
    }
    
  }
  func convertStringToDictionary(_ text: String) -> [String:AnyObject]? {
    do {
      return try JSONSerialization.jsonObject(with: Data(text.utf8), options: []) as? [String:AnyObject]
    } catch let error as NSError {
      print(error)
      return nil
    }
  }
  
  func dataReceivedInChannel(_ data: Data) {
    let dataAsString = String(decoding: data, as: UTF8.self)
    let alert = UIAlertController(title: "", message:dataAsString, preferredStyle: .alert)
    alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in })
    self.present(alert, animated: true){}
  }
}
