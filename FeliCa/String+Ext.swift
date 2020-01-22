//
//  String+Ext.swift
//  FeliCa
//
//  Created by Kazutoshi Baba on 2020/01/22.
//  Copyright © 2020 COCOABAGEL. All rights reserved.
//

import Foundation

extension String {
    func toBytes() -> [UInt8]? {
        let length = self.count
        if length & 1 != 0 {
            return nil
        }
        var bytes = [UInt8]()
        bytes.reserveCapacity(length/2)
        var index = self.startIndex
        for _ in 0..<length/2 {
            let nextIndex = self.index(index, offsetBy: 2)
            if let b = UInt8(self[index..<nextIndex], radix: 16) {
                bytes.append(b)
            } else {
                return nil
            }
            index = nextIndex
        }
        return bytes
    }
}
