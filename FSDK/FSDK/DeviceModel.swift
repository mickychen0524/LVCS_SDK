//
//  DeviceModel.swift
//  WifiClerkChat
//
//  Created by Swayam Agrawal on 31/08/17.
//  Copyright © 2017 Avviotech. All rights reserved.
//

import Foundation
import MultipeerConnectivity

public class DeviceModel
{
    let peerID : MCPeerID
    let type : String
    let status : String
    
    init(p:MCPeerID,t:String,s:String)
    {
        self.peerID = p
        self.type = t
        self.status = s
    }
}
