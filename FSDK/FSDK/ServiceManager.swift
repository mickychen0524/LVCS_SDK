//
//  ServiceManager.swift
//  WifiChat
//
//  Created by Swayam Agrawal on 25/08/17.
//  Copyright © 2017 Avviotech. All rights reserved.
//

import Foundation
import MultipeerConnectivity

public protocol ServiceManagerProtocol {
    func connectedDevicesChanged(_ manager : ServiceManager, connectedDevices: [MCPeerID:DeviceModel])
    func receivedData(_ manager : ServiceManager, peerID : MCPeerID, responseString: String)
}


import Foundation

public class ServiceManager : NSObject {
    static var sharedServiceManager:ServiceManager? = nil
    fileprivate let serviceType = "webrtc-service"
    fileprivate let myPeerId = MCPeerID(displayName: UIDevice.current.name)
    fileprivate var serviceAdvertiser : MCNearbyServiceAdvertiser
    fileprivate var serviceBrowser : MCNearbyServiceBrowser
    var selectedPeer:MCPeerID?
    public var delegate : ServiceManagerProtocol?
    var allDevice = [MCPeerID:DeviceModel]()
    var clerkList = [MCPeerID:DeviceModel]()
    var appType:String = ""
    init(type:String) {
        let dInfo:[String : String] = ["type":type]
        self.serviceAdvertiser = MCNearbyServiceAdvertiser(peer: myPeerId, discoveryInfo: dInfo, serviceType: serviceType)
        self.serviceBrowser = MCNearbyServiceBrowser(peer: myPeerId, serviceType: serviceType)
        super.init()
        
        if type == "clerk"
        {
            self.serviceAdvertiser.startAdvertisingPeer()
            self.serviceBrowser.startBrowsingForPeers()
            self.serviceAdvertiser.delegate = self
            self.serviceBrowser.delegate = self
            
        }
        else{
            self.serviceBrowser.startBrowsingForPeers()
            self.serviceBrowser.delegate = self
        }
        
    }
    
    public static func getManager(t:String) -> ServiceManager
    {
        if sharedServiceManager == nil
        {
            sharedServiceManager = ServiceManager(type: t)
        }
        return sharedServiceManager!
    }
    
    public func stopAdvertising()
    {
        self.serviceAdvertiser.stopAdvertisingPeer()
    }
    
    
    public func startAdvertising(type:String)
    {
        self.appType = type
        
        self.serviceAdvertiser.startAdvertisingPeer()
        self.serviceAdvertiser.delegate = self
    }
    
    
    
    deinit {
        self.serviceAdvertiser.stopAdvertisingPeer()
        self.serviceBrowser.stopBrowsingForPeers()
    }
    
    lazy var session: MCSession = {
        let session = MCSession(peer: self.myPeerId, securityIdentity: nil, encryptionPreference: MCEncryptionPreference.none)
        session.delegate = self
        return session
    }()
    
    
    
    func sendColor(_ colorName : String) {
        print("sendColor: \(colorName)")
        if self.session.connectedPeers.count > 0 {
            var error : NSError?
            do {
                try self.session.send(colorName.data(using: String.Encoding.utf8, allowLossyConversion: false)!, toPeers: session.connectedPeers, with: MCSessionSendDataMode.reliable)
            } catch let error1 as NSError {
                error = error1
                print("Error \(String(describing: error))")
            }
        }
    }
    
    
    public func callRequest(_ recipient : String, index : MCPeerID) {
        var isError:Bool = false
        if self.session.connectedPeers.count > 0 {
            var error : NSError?
            do {
                try self.session.send(recipient.data(using: String.Encoding.utf8, allowLossyConversion: false)!, toPeers: [index], with: MCSessionSendDataMode.reliable)
                self.selectedPeer = index
                
                print("connected peers --- > \(index)")
            } catch let error1 as NSError {
                isError = true
                error = error1
                print("\(String(describing: error))")
            }
            
            if !isError
            {
                DispatchQueue.main.async {
                    self.allDevice.removeValue(forKey: index)
                    self.delegate?.connectedDevicesChanged(self, connectedDevices: self.allDevice)
                }
                
            }
        }
        
    }
    
    public func sendDataToSelectedPeer(_ json:Dictionary<String,AnyObject>){
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: json, options: JSONSerialization.WritingOptions.prettyPrinted)
            try self.session.send(jsonData, toPeers: [self.selectedPeer!], with: MCSessionSendDataMode.reliable)
            print("command \(json) --- > \(String(describing: self.selectedPeer?.displayName))")
        } catch let error1 as NSError {
            print("\(error1)")
        }
    }
    
    
    
}

extension ServiceManager : MCNearbyServiceAdvertiserDelegate {
    @available(iOS 7.0, *)
    public func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID, withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        invitationHandler(true, self.session)
    }
    
    
    public func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didNotStartAdvertisingPeer error: Error) {
        print("didNotStartAdvertisingPeer: \(error)")
    }
    
    
}

extension ServiceManager : MCNearbyServiceBrowserDelegate {
    
    public func browser(_ browser: MCNearbyServiceBrowser, didNotStartBrowsingForPeers error: Error) {
        print("didNotStartBrowsingForPeers: \(error)")
    }
    
    public func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String : String]?) {
        print("foundPeer: \(peerID)")
        print("invitePeer: \(peerID)")
        let type = info?["type"]!
        print("withDiscoveryInfo: \(String(describing: type))")
        let shouldInvite = (myPeerId.displayName.compare(peerID.displayName) == .orderedDescending)
        
        if type == "clerk"
        {
            print("clerk connected device")
            let dm = DeviceModel(p:peerID,t: type!,s:"Pending")
            self.clerkList.updateValue(dm, forKey: peerID)
        }

        
        if shouldInvite
        {
            browser.invitePeer(peerID, to: self.session, withContext: nil, timeout: 60)
        }
        
        if type != self.appType && !(type?.isEmpty)!
        {
            print("client connected device" +  self.appType)
            let dm = DeviceModel(p:peerID,t: type!,s:"Pending")
            self.allDevice.updateValue(dm, forKey: peerID)
            self.delegate?.connectedDevicesChanged(self, connectedDevices: self.allDevice)
        }
        
    }
    
    public func getClerkList() -> [MCPeerID:DeviceModel]
    {
        return self.clerkList
    }
    
    public func getClientList() -> [MCPeerID:DeviceModel]
    {
        return self.allDevice
    }
    
    public func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        print("lostPeer: \(peerID)")
        allDevice.removeValue(forKey: peerID)
        self.delegate?.connectedDevicesChanged(self, connectedDevices: allDevice)
        
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

extension ServiceManager : MCSessionDelegate {
    
    public func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        print("peer \(peerID) didChangeState: \(state.stringValue())")
        self.delegate?.connectedDevicesChanged(self, connectedDevices: allDevice)
        print(session.connectedPeers.map({$0.displayName}))
        if allDevice.index(forKey: peerID) != nil{
            if state.stringValue() != "NotConnected"
            {
                allDevice.updateValue(allDevice[peerID]!, forKey: peerID)
                self.delegate?.connectedDevicesChanged(self, connectedDevices: allDevice)
            }
            else{
                
                let shouldInvite = (myPeerId.displayName.compare(peerID.displayName) == .orderedDescending)
                if shouldInvite
                {
                    self.serviceBrowser.invitePeer(peerID, to: self.session, withContext: nil, timeout: 60)
                }
                clerkList.removeValue(forKey: peerID)
                allDevice.removeValue(forKey: peerID)
                self.delegate?.connectedDevicesChanged(self, connectedDevices: allDevice)
            }
            
        }
        var arr:[String] = session.connectedPeers.map({$0.displayName})
        if arr.count > 0 {
            print(arr[0])
        }
        
    }
    
    public func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        
        let str = NSString(data: data, encoding: String.Encoding.utf8.rawValue)! as String
        print("didReceiveData: \(str) from \(peerID.displayName) bytes")
        //let peerId = peerID.displayName
        self.delegate?.receivedData(self, peerID: peerID, responseString: str)
    }
    
    public func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {
        print("didReceiveStream")
    }
    
    public func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL, withError error: Error?) {
        print("didFinishReceivingResourceWithName")
    }
    
    public func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {
        print("didStartReceivingResourceWithName")
    }
    
}

public extension Dictionary {
    subscript(i:Int) -> (key:Key,value:Value) {
        get {
            return self[index(startIndex, offsetBy: i)];
        }
    }
}
