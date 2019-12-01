//
//  AppDelegate.swift
//  key
//
//  Created by 用实力让情怀落地 on 2019/12/2.
//  Copyright © 2019 用实力让情怀落地. All rights reserved.
//

struct KeyPair {
    static let manager: EllipticCurveKeyPair.Manager = {
        let publicAccessControl = EllipticCurveKeyPair.AccessControl(protection: kSecAttrAccessibleAlwaysThisDeviceOnly, flags: [])
        let privateAccessControl = EllipticCurveKeyPair.AccessControl(protection: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly, flags: [.userPresence, .privateKeyUsage])
        let config = EllipticCurveKeyPair.Config(
            publicLabel: "payment.sign.public",
            privateLabel: "payment.sign.private",
            operationPrompt: "Confirm payment",
            publicKeyAccessControl: publicAccessControl,
            privateKeyAccessControl: privateAccessControl,
            token: .secureEnclave)
        return EllipticCurveKeyPair.Manager(config: config)
    }()
}
