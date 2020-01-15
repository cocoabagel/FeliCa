//
//  FeliCa.swift
//  FeliCa
//
//  Created by Kazutoshi Baba on 2020/01/15.
//  Copyright © 2020 COCOABAGEL. All rights reserved.
//

import PromiseKit
import CoreNFC

enum FeliCaError: Error {
    case notSupported
    case connection
    case notFeliCa
    case writeError
    case readError
    case sessionInvalidated
}

public class Felica: NSObject {
    public var didFinishScan: (([Data]) -> Void)?
    public var didFailWithError: ((Error) -> Void)?
    
    private var session: NFCTagReaderSession?
    
    func scan() {
        guard NFCTagReaderSession.readingAvailable else {
            didFailWithError?(FeliCaError.notSupported)
            return
        }
        session = NFCTagReaderSession(pollingOption: .iso18092, delegate: self)
        session?.alertMessage = "Hold your iPhone near the tag."
        session?.begin()
    }
}

// MARK: NFCTagReaderSessionDelegate
extension Felica: NFCTagReaderSessionDelegate {
    public func tagReaderSessionDidBecomeActive(_ session: NFCTagReaderSession) {
    }
    
    public func tagReaderSession(_ session: NFCTagReaderSession, didInvalidateWithError error: Error) {
        didFailWithError?(FeliCaError.sessionInvalidated)
    }
    
    public func tagReaderSession(_ session: NFCTagReaderSession, didDetect tags: [NFCTag]) {
        guard tags.count == 1 else {
            let retryInterval = DispatchTimeInterval.milliseconds(500)
            session.alertMessage = "More than 1 tag is detected, Please try again."
            DispatchQueue.global().asyncAfter(deadline: .now() + retryInterval, execute: {
                session.restartPolling()
            })
            return
        }
        
        let tag = tags.first!
        firstly {
            connectFeliCaTag(session: session, detect: tag)
        }.then { tag -> Promise<NFCFeliCaTag> in
            self.writeWithoutEncryption(feliCaTag: tag)
        }.then { tag -> Promise<[Data]> in
            self.readWithoutEncryption(feliCaTag: tag)
        }.done { dataList in
            let id = dataList[0].map { String(format: "%.2hhx", $0) }.joined()
            print("ID: \(id)")
            let ckv = dataList[1][0...1].reduce(0) { v, byte in
                return v << 8 | Int(byte)
            }
            print("CKV: \(ckv)")
            let maca = dataList[2].map { String(format: "%.2hhx", $0) }.joined()
            print("MAC_A: \(maca)")
            session.alertMessage = "ID: \(id)\nCKV: \(ckv)\nMAC_A: \(maca)"
            session.invalidate()
            self.didFinishScan?(dataList)
        }.catch { error in
            guard let error = error as? FeliCaError else {
                session.invalidate(errorMessage: "Unknown Error. Please try again.")
                return
            }
            switch error {
            case .connection:
                session.invalidate(errorMessage: "Connection error. Please try again.")
            case .notFeliCa:
                session.invalidate(errorMessage: "A tag that is Not FeliCa. Please try again.")
            case .writeError:
                session.invalidate(errorMessage: "Write error. Please try again.")
            case .readError:
                session.invalidate(errorMessage: "Read error. Please try again.")
            default:
                session.invalidate(errorMessage: "Some error has occurred. Please try again.")
            }
        }
    }
    
    private func connectFeliCaTag(session: NFCTagReaderSession, detect tag: NFCTag) -> Promise<NFCFeliCaTag> {
        return Promise { seal in
            session.connect(to: tag) { error in
                if error != nil {
                    seal.resolve(nil, FeliCaError.connection)
                    return
                }

                guard case .feliCa(let feliCaTag) = tag else {
                    seal.resolve(nil, FeliCaError.notFeliCa)
                    return
                }
                
                seal.resolve(feliCaTag, nil)
            }
        }
    }
    
    private func writeWithoutEncryption(feliCaTag: NFCFeliCaTag) -> Promise<NFCFeliCaTag> {
        return Promise { seal in
            let serviceCodeList = [Data([0x09, 0x00])] // Read,Write
            let blockList = [Data([0x80, 0x80])] // RC
            let blockData = [Data([0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00])] // RC values

            feliCaTag.writeWithoutEncryption(serviceCodeList: serviceCodeList, blockList: blockList, blockData: blockData) { (status1, status2, error) in
                
                guard error == nil, status1 == 0, status2 == 0 else {
                    seal.resolve(nil, FeliCaError.writeError)
                    return
                }
                
                seal.resolve(feliCaTag, nil)
            }
        }
    }
    
    private func readWithoutEncryption(feliCaTag: NFCFeliCaTag) -> Promise<[Data]> {
        return Promise { seal in
            let serviceCodeList = [Data([0x0b, 0x00])] // Read Only
            let blockList = [Data([0x80, 0x82]), Data([0x80, 0x86]), Data([0x80, 0x91])] // id, ckv, mac_a
            
            feliCaTag.readWithoutEncryption(serviceCodeList: serviceCodeList, blockList: blockList) { (status1, status2, dataList, error) in
                guard error == nil, status1 == 0, status2 == 0 else {
                    seal.resolve(nil, FeliCaError.readError)
                    return
                }
                seal.resolve(dataList, nil)
             }
        }
    }
}
