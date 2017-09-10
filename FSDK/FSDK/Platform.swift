//
//  Platform.swift
//  FSDK
//
//  Created by Swayam Agrawal on 10/09/17.
//  Copyright © 2017 Avviotech. All rights reserved.
//

import Foundation


struct Platform {
    
    static var isSimulator: Bool {
        return TARGET_OS_SIMULATOR != 0
    }
}
