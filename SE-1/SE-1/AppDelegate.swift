//
//  AppDelegate.swift
//  SE-1
//
//  Created by 用实力让情怀落地 on 2019/12/3.
//  Copyright © 2019 用实力让情怀落地. All rights reserved.
//

import Foundation
import Security
import LocalAuthentication

@available(OSX 10.12.1, iOS 9.0, *)
public enum EllipticCurveKeyPair {
    
    public typealias Logger = (String) -> ()
    public static var logger: Logger?
        
    public struct Config {
        
        // The label used to identify the public key in keychain
        public var publicLabel: String
        
        // The label used to identify the private key on the secure enclave
        public var privateLabel: String
        
        // The text presented to the user about why we need his/her fingerprint / device pin
        // If you are passing an LAContext to sign or decrypt this value will be rejected
        public var operationPrompt: String?
        
        // The access control used to manage the access to the public key
        public var publicKeyAccessControl: AccessControl
        
        // The access control used to manage the access to the private key
        public var privateKeyAccessControl: AccessControl
        
        // The access group e.g. "BBDV3R8HVV.no.agens.demo"
        // Useful for shared keychain items
        public var publicKeyAccessGroup: String?
        
        // The access group e.g. "BBDV3R8HVV.no.agens.demo"
        // Useful for shared keychain items
        public var privateKeyAccessGroup: String?
        
        // Should it be stored on .secureEnclave or in .keychain ?
        public var token: Token
        
        public init(publicLabel: String,
                    privateLabel: String,
                    operationPrompt: String?,
                    publicKeyAccessControl: AccessControl,
                    privateKeyAccessControl: AccessControl,
                    publicKeyAccessGroup: String? = nil,
                    privateKeyAccessGroup: String? = nil,
                    token: Token) {
            self.publicLabel = publicLabel
            self.privateLabel = privateLabel
            self.operationPrompt = operationPrompt
            self.publicKeyAccessControl = publicKeyAccessControl
            self.privateKeyAccessControl = privateKeyAccessControl
            self.publicKeyAccessGroup = publicKeyAccessGroup
            self.privateKeyAccessGroup = privateKeyAccessGroup
            self.token = token
        }
    }
    
    // A stateful and opiniated manager for using the secure enclave and keychain
    // If the private or public key is not found this manager will naively just recreate a new keypair
    // If the device doesn't have a Secure Enclave it will store the private key in keychain just like the public key
    //
    // If you think this manager is "too smart" in that sense you may use this manager as an example
    // and create your own manager
    public final class Manager {
        
        private let config: Config
        private let helper: Helper
        private var cachedPublicKey: PublicKey? = nil
        private var cachedPrivateKey: PrivateKey? = nil
        
        public init(config: Config) {
            self.config = config
            self.helper = Helper(config: config)
        }
        
        public func deleteKeyPair() throws {
            clearCache()
            try helper.delete()
        }
        
        public func publicKey() throws -> PublicKey {
            do {
                if let key = cachedPublicKey {
                    return key
                }
                let key = try helper.getPublicKey()
                cachedPublicKey = key
                return key
            } catch EllipticCurveKeyPair.Error.underlying(_, let underlying) where underlying.code == errSecItemNotFound {
                let keys = try helper.generateKeyPair()
                cachedPublicKey = keys.public
                cachedPrivateKey = keys.private
                return keys.public
            } catch {
                throw error
            }
        }
        
        public func privateKey(context: LAContext? = nil) throws -> PrivateKey {
            do {
                if cachedPrivateKey?.context !== context {
                    cachedPrivateKey = nil
                }
                if let key = cachedPrivateKey {
                    return key
                }
                let key = try helper.getPrivateKey(context: context)
                cachedPrivateKey = key
                return key
            } catch EllipticCurveKeyPair.Error.underlying(_, let underlying) where underlying.code == errSecItemNotFound {
                if config.publicKeyAccessControl.flags.contains(.privateKeyUsage) == false, (try? helper.getPublicKey()) != nil {
                    throw Error.probablyAuthenticationError(underlying: underlying)
                }
                let keys = try helper.generateKeyPair(context: nil)
                cachedPublicKey = keys.public
                cachedPrivateKey = keys.private
                return keys.private
            } catch {
                throw error
            }
        }
        
        public func keys(context: LAContext? = nil) throws -> (`public`: PublicKey, `private`: PrivateKey) {
            let privateKey = try self.privateKey(context: context)
            let publicKey = try self.publicKey()
            return (public: publicKey, private: privateKey)
        }
        
        public func clearCache() {
            cachedPublicKey = nil
            cachedPrivateKey = nil
        }
        
        @available(iOS 10, *)
        public func sign(_ digest: Data, hash: Hash, context: LAContext? = nil) throws -> Data {
            return try helper.sign(digest, privateKey: privateKey(context: context), hash: hash)
        }
        
        @available(OSX, unavailable)
        @available(iOS, deprecated: 10.0, message: "This method and extra complexity will be removed when 9.0 is obsolete.")
        public func signUsingSha256(_ digest: Data, context: LAContext? = nil) throws -> Data {
            #if os(iOS)
                return try helper.signUsingSha256(digest, privateKey: privateKey(context: context))
            #else
                throw Error.inconcistency(message: "Should be unreachable.")
            #endif
        }
        
        @available(iOS 10, *)
        public func verify(signature: Data, originalDigest: Data, hash: Hash) throws {
            try helper.verify(signature: signature, digest: originalDigest, publicKey: publicKey(), hash: hash)
        }
        
        @available(OSX, unavailable)
        @available(iOS, deprecated: 10.0, message: "This method and extra complexity will be removed when 9.0 is obsolete.")
        public func verifyUsingSha256(signature: Data, originalDigest: Data) throws  {
            #if os(iOS)
                try helper.verifyUsingSha256(signature: signature, digest: originalDigest, publicKey: publicKey())
            #else
                throw Error.inconcistency(message: "Should be unreachable.")
            #endif
        }
        
        @available(iOS 10.3, *) // API available at 10.0, but bugs made it unusable on versions lower than 10.3
        public func encrypt(_ digest: Data, hash: Hash = .sha256) throws -> Data {
            return try helper.encrypt(digest, publicKey: publicKey(), hash: hash)
        }
        
        @available(iOS 10.3, *) // API available at 10.0, but bugs made it unusable on versions lower than 10.3
        public func decrypt(_ encrypted: Data, hash: Hash = .sha256, context: LAContext? = nil) throws -> Data {
            return try helper.decrypt(encrypted, privateKey: privateKey(context: context), hash: hash)
        }
        
    }
    
    // Helper is a stateless class for querying the secure enclave and keychain
    // You may create a small stateful facade around this
    // `Manager` is an example of such an opiniated facade
    public struct Helper {
        
        // The user visible label in the device's key chain
        public let config: Config
        
        public init() {}
        
        public func getPublicKey() throws -> PublicKey {
            return try Query.getPublicKey(labeled: config.publicLabel, accessGroup: config.publicKeyAccessGroup)
        }
        
        public func getPrivateKey(context: LAContext? = nil) throws -> PrivateKey {
            let context = context ?? LAContext()
            return try Query.getPrivateKey(labeled: config.privateLabel, accessGroup: config.privateKeyAccessGroup, prompt: config.operationPrompt, context: context)
        }
        
        public func getKeys(context: LAContext? = nil) throws -> (`public`: PublicKey, `private`: PrivateKey) {
            let privateKey = try getPrivateKey(context: context)
            let publicKey = try getPublicKey()
            return (public: publicKey, private: privateKey)
        }
        
        public func generateKeyPair(context: LAContext? = nil) throws -> (`public`: PublicKey, `private`: PrivateKey) {
            guard config.privateLabel != config.publicLabel else{
                throw Error.inconcistency(message: "Public key and private key can not have same label")
            }
            let context = context ?? LAContext()
            let query = try Query.generateKeyPairQuery(config: config, token: config.token, context: context)
            var publicOptional, privateOptional: SecKey?
            logger?("SecKeyGeneratePair: \(query)")
            let status = SecKeyGeneratePair(query as CFDictionary, &publicOptional, &privateOptional)
            guard status == errSecSuccess else {
                if status == errSecAuthFailed {
                    throw Error.osStatus(message: "Could not generate keypair. Security probably doesn't like the access flags you provided. Specifically if this device doesn't have secure enclave and you pass `.privateKeyUsage`. it will produce this error.", osStatus: status)
                } else {
                    throw Error.osStatus(message: "Could not generate keypair.", osStatus: status)
                }
            }
            guard let publicSec = publicOptional, let privateSec = privateOptional else {
                throw Error.inconcistency(message: "Created private public key pair successfully, but weren't able to retreive it.")
            }
            let publicKey = PublicKey(publicSec)
            let privateKey = PrivateKey(privateSec, context: context)
            try Query.forceSavePublicKey(publicKey, label: config.publicLabel)
            return (public: publicKey, private: privateKey)
        }
        
        public func delete() throws {
            try Query.deletePublicKey(labeled: config.publicLabel, accessGroup: config.publicKeyAccessGroup)
            try Query.deletePrivateKey(labeled: config.privateLabel, accessGroup: config.privateKeyAccessGroup)
        }
        
        @available(iOS 10.0, *)
        public func sign(_ digest: Data, privateKey: PrivateKey, hash: Hash) throws -> Data {
            Helper.logToConsoleIfExecutingOnMainThread()
            var error : Unmanaged<CFError>?
            let result = SecKeyCreateSignature(privateKey.underlying, hash.signatureMessage, digest as CFData, &error)
            guard let signature = result else {
                throw Error.fromError(error?.takeRetainedValue(), message: "Could not create signature.")
            }
            return signature as Data
        }
        
        @available(OSX, unavailable)
        @available(iOS, deprecated: 10.0, message: "This method and extra complexity will be removed when 9.0 is obsolete.")
        public func signUsingSha256(_ digest: Data, privateKey: PrivateKey) throws -> Data {
            #if os(iOS)
                Helper.logToConsoleIfExecutingOnMainThread()
                let digestToSign = digest.sha256()
                
                var digestToSignBytes = [UInt8](repeating: 0, count: digestToSign.count)
                digestToSign.copyBytes(to: &digestToSignBytes, count: digestToSign.count)
                
                var signatureBytes = [UInt8](repeating: 0, count: 128)
                var signatureLength = 128
                
                let signErr = SecKeyRawSign(privateKey.underlying, .PKCS1, &digestToSignBytes, digestToSignBytes.count, &signatureBytes, &signatureLength)
                guard signErr == errSecSuccess else {
                    throw Error.osStatus(message: "Could not create signature.", osStatus: signErr)
                }
                
                let signature = Data(bytes: &signatureBytes, count: signatureLength)
                return signature
            #else
                throw Error.inconcistency(message: "Should be unreachable.")
            #endif
        }
        
        @available(iOS 10.0, *)
        public func verify(signature: Data, digest: Data, publicKey: PublicKey, hash: Hash) throws {
            var error : Unmanaged<CFError>?
            let valid = SecKeyVerifySignature(publicKey.underlying, hash.signatureMessage, digest as CFData, signature as CFData, &error)
            if let error = error?.takeRetainedValue() {
                throw Error.fromError(error, message: "Could not verify signature.")
            }
            guard valid == true else {
                throw Error.inconcistency(message: "Signature yielded no error, but still marks itself as unsuccessful")
            }
        }
        
        @available(OSX, unavailable)
        @available(iOS, deprecated: 10.0, message: "This method and extra complexity will be removed when 9.0 is obsolete.")
        public func verifyUsingSha256(signature: Data, digest: Data, publicKey: PublicKey) throws {
            #if os(iOS)
                let sha = digest.sha256()
                var shaBytes = [UInt8](repeating: 0, count: sha.count)
                sha.copyBytes(to: &shaBytes, count: sha.count)
                
                var signatureBytes = [UInt8](repeating: 0, count: signature.count)
                signature.copyBytes(to: &signatureBytes, count: signature.count)
                
                let status = SecKeyRawVerify(publicKey.underlying, .PKCS1, &shaBytes, shaBytes.count, &signatureBytes, signatureBytes.count)
                guard status == errSecSuccess else {
                    throw Error.osStatus(message: "Could not verify signature.", osStatus: status)
                }
            #else
                throw Error.inconcistency(message: "Should be unreachable.")
            #endif
        }
        
        @available(iOS 10.3, *)
        public func encrypt(_ digest: Data, publicKey: PublicKey, hash: Hash) throws -> Data {
            var error : Unmanaged<CFError>?
            let result = SecKeyCreateEncryptedData(publicKey.underlying, hash.encryptionEciesEcdh, digest as CFData, &error)
            guard let data = result else {
                throw Error.fromError(error?.takeRetainedValue(), message: "Could not encrypt.")
            }
            return data as Data
        }
        
        @available(iOS 10.3, *)
        public func decrypt(_ encrypted: Data, privateKey: PrivateKey, hash: Hash) throws -> Data {
            Helper.logToConsoleIfExecutingOnMainThread()
            var error : Unmanaged<CFError>?
            let result = SecKeyCreateDecryptedData(privateKey.underlying, hash.encryptionEciesEcdh, encrypted as CFData, &error)
            guard let data = result else {
                throw Error.fromError(error?.takeRetainedValue(), message: "Could not decrypt.")
            }
            return data as Data
        }
        
        public static func logToConsoleIfExecutingOnMainThread() {
            if Thread.isMainThread {
                let _ = LogOnce.shouldNotBeMainThread
            }
        }
    }
    
    private struct LogOnce {
        static var shouldNotBeMainThread: Void = {
            print("[WARNING] \(EllipticCurveKeyPair.self): Decryption and signing should be done off main thread because LocalAuthentication may need the thread to show UI. This message is logged only once.")
        }()
    }
    
    private struct Query {
        
        static func getKey(_ query: [String: Any]) throws -> SecKey {
            var raw: CFTypeRef?
            logger?("SecItemCopyMatching: \(query)")
            let status = SecItemCopyMatching(query as CFDictionary, &raw)
            guard status == errSecSuccess, let result = raw else {
                throw Error.osStatus(message: "Could not get key for query: \(query)", osStatus: status)
            }
            return result as! SecKey
        }
        
        static func publicKeyQuery(labeled: String, accessGroup: String?) -> [String:Any] {
            var params: [String:Any] = [
                kSecClass as String: kSecClassKey,
                kSecAttrKeyClass as String: kSecAttrKeyClassPublic,
                kSecAttrLabel as String: labeled,
                kSecReturnRef as String: true,
            ]
            if let accessGroup = accessGroup {
                params[kSecAttrAccessGroup as String] = accessGroup
            }
            return params
        }
        
        static func privateKeyQuery(labeled: String, accessGroup: String?, prompt: String?, context: LAContext?) -> [String: Any] {
            var params: [String:Any] = [
                kSecClass as String: kSecClassKey,
                kSecAttrKeyClass as String: kSecAttrKeyClassPrivate,
                kSecAttrLabel as String: labeled,
                kSecReturnRef as String: true,
                ]
            if let accessGroup = accessGroup {
                params[kSecAttrAccessGroup as String] = accessGroup
            }
            if let prompt = prompt {
                params[kSecUseOperationPrompt as String] = prompt
            }
            if let context = context {
                params[kSecUseAuthenticationContext as String] = context
            }
            return params
        }
        
        static func generateKeyPairQuery(config: Config, token: Token, context: LAContext? = nil) throws -> [String:Any] {
            
            /* ========= private ========= */
            var privateKeyParams: [String: Any] = [
                kSecAttrLabel as String: config.privateLabel,
                kSecAttrIsPermanent as String: true,
                kSecUseAuthenticationUI as String: kSecUseAuthenticationUIAllow,
                ]
            if let privateKeyAccessGroup = config.privateKeyAccessGroup {
                privateKeyParams[kSecAttrAccessGroup as String] = privateKeyAccessGroup
            }
            if let context = context {
                privateKeyParams[kSecUseAuthenticationContext as String] = context
            }
            
            // On iOS 11 and lower: access control with empty flags doesn't work
            if !config.privateKeyAccessControl.flags.isEmpty {
                privateKeyParams[kSecAttrAccessControl as String] = try config.privateKeyAccessControl.underlying()
            } else {
                privateKeyParams[kSecAttrAccessible as String] = config.privateKeyAccessControl.protection
            }
            
            /* ========= public ========= */
            var publicKeyParams: [String: Any] = [
                kSecAttrLabel as String: config.publicLabel,
                ]
            if let publicKeyAccessGroup = config.publicKeyAccessGroup {
                publicKeyParams[kSecAttrAccessGroup as String] = publicKeyAccessGroup
            }
            
            // On iOS 11 and lower: access control with empty flags doesn't work
            if !config.publicKeyAccessControl.flags.isEmpty {
                publicKeyParams[kSecAttrAccessControl as String] = try config.publicKeyAccessControl.underlying()
            } else {
                publicKeyParams[kSecAttrAccessible as String] = config.publicKeyAccessControl.protection
            }
            
            /* ========= combined ========= */
            var params: [String: Any] = [
                kSecAttrKeyType as String: Constants.attrKeyTypeEllipticCurve,
                kSecPrivateKeyAttrs as String: privateKeyParams,
                kSecPublicKeyAttrs as String: publicKeyParams,
                kSecAttrKeySizeInBits as String: 256,
                ]
            if token == .secureEnclave {
                params[kSecAttrTokenID as String] = kSecAttrTokenIDSecureEnclave
            }
            return params
        }
        
        static func getPublicKey(labeled: String, accessGroup: String?) throws -> PublicKey {
            let query = publicKeyQuery(labeled: labeled, accessGroup: accessGroup)
            return PublicKey(try getKey(query))
        }
        
        static func getPrivateKey(labeled: String, accessGroup: String?, prompt: String?, context: LAContext? = nil) throws -> PrivateKey {
            let query = privateKeyQuery(labeled: labeled, accessGroup: accessGroup, prompt: prompt, context: context)
            return PrivateKey(try getKey(query), context: context)
        }
        
        static func deletePublicKey(labeled: String, accessGroup: String?) throws {
            let query = publicKeyQuery(labeled: labeled, accessGroup: accessGroup) as CFDictionary
            logger?("SecItemDelete: \(query)")
            let status = SecItemDelete(query as CFDictionary)
            guard status == errSecSuccess || status == errSecItemNotFound else {
                throw Error.osStatus(message: "Could not delete public key.", osStatus: status)
            }
        }
        
        static func deletePrivateKey(labeled: String, accessGroup: String?) throws {
            let query = privateKeyQuery(labeled: labeled, accessGroup: accessGroup, prompt: nil, context: nil) as CFDictionary
            logger?("SecItemDelete: \(query)")
            let status = SecItemDelete(query as CFDictionary)
            guard status == errSecSuccess || status == errSecItemNotFound else {
                throw Error.osStatus(message: "Could not delete private key.", osStatus: status)
            }
        }
        
        static func forceSavePublicKey(_ publicKey: PublicKey, label: String) throws {
            let query: [String: Any] = [
                kSecClass as String: kSecClassKey,
                kSecAttrLabel as String: label,
                kSecValueRef as String: publicKey.underlying
            ]
            var raw: CFTypeRef?
            logger?("SecItemAdd: \(query)")
            var status = SecItemAdd(query as CFDictionary, &raw)
            if status == errSecDuplicateItem {
                logger?("SecItemDelete: \(query)")
                status = SecItemDelete(query as CFDictionary)
                logger?("SecItemAdd: \(query)")
                status = SecItemAdd(query as CFDictionary, &raw)
            }
            if status == errSecInvalidRecord {
                throw Error.osStatus(message: "Could not save public key. It is possible that the access control you have provided is not supported on this OS and/or hardware.", osStatus: status)
            } else if status != errSecSuccess {
                throw Error.osStatus(message: "Could not save public key", osStatus: status)
            }
        }
    }
    
    public struct Constants {
        public static let noCompression: UInt8 = 4
        public static let attrKeyTypeEllipticCurve: String = {
            if #available(iOS 10.0, *) {
                return kSecAttrKeyTypeECSECPrimeRandom as String
            } else {
                return kSecAttrKeyTypeEC as String
            }
        }()
    }
    
    public final class PublicKeyData {
        
        // As received from Security framework
        public let raw: Data
        
        // The open ssl compatible DER format X.509
        //
        // We take the raw key and prepend an ASN.1 headers to it. The end result is an
        // ASN.1 SubjectPublicKeyInfo structure, which is what OpenSSL is looking for.
        //
        // See the following DevForums post for more details on this.
        // https://forums.developer.apple.com/message/84684#84684
        //
        // End result looks like this
        // https://lapo.it/asn1js/#3059301306072A8648CE3D020106082A8648CE3D030107034200041F4E3F6CD8163BCC14505EBEEC9C30971098A7FA9BFD52237A3BCBBC48009162AAAFCFC871AC4579C0A180D5F207316F74088BF01A31F83E9EBDC029A533525B
        //
        public lazy var DER: Data = {
            var x9_62HeaderECHeader = [UInt8]([
                /* sequence          */ 0x30, 0x59,
                /* |-> sequence      */ 0x30, 0x13,
                /* |---> ecPublicKey */ 0x06, 0x07, 0x2A, 0x86, 0x48, 0xCE, 0x3D, 0x02, 0x01, // http://oid-info.com/get/1.2.840.10045.2.1 (ANSI X9.62 public key type)
                /* |---> prime256v1  */ 0x06, 0x08, 0x2A, 0x86, 0x48, 0xCE, 0x3D, 0x03, 0x01, // http://oid-info.com/get/1.2.840.10045.3.1.7 (ANSI X9.62 named elliptic curve)
                /* |-> bit headers   */ 0x07, 0x03, 0x42, 0x00
                ])
            var result = Data()
            result.append(Data(x9_62HeaderECHeader))
            result.append(self.raw)
            return result
        }()
        
        public lazy var PEM: String = {
            var lines = String()
            lines.append("-----BEGIN PUBLIC KEY-----\n")
            lines.append(self.DER.base64EncodedString(options: [.lineLength64Characters, .endLineWithCarriageReturn]))
            lines.append("\n-----END PUBLIC KEY-----")
            return lines
        }()
        
        internal init(_ raw: Data) {
            self.raw = raw
        }
    }
    
    public class Key {
        
        public let underlying: SecKey
        
        internal init(_ underlying: SecKey) {
            self.underlying = underlying
        }
        
        private var cachedAttributes: [String:Any]? = nil
        
        public func attributes() throws -> [String:Any] {
            if let attributes = cachedAttributes {
                return attributes
            } else {
                let attributes = try queryAttributes()
                cachedAttributes = attributes
                return attributes
            }
        }
        
        public func label() throws -> String {
            guard let attribute = try self.attributes()[kSecAttrLabel as String] as? String else {
                throw Error.inconcistency(message: "We've got a private key, but we are missing its label.")
            }
            return attribute
        }
        
        public func accessGroup() throws -> String? {
            return try self.attributes()[kSecAttrAccessGroup as String] as? String
        }
        
        public func accessControl() throws -> SecAccessControl {
            guard let attribute = try self.attributes()[kSecAttrAccessControl as String] else {
                throw Error.inconcistency(message: "We've got a private key, but we are missing its access control.")
            }
            return attribute as! SecAccessControl
        }
        
        private func queryAttributes() throws -> [String:Any] {
            var matchResult: AnyObject? = nil
            let query: [String:Any] = [
                kSecClass as String: kSecClassKey,
                kSecValueRef as String: underlying,
                kSecReturnAttributes as String: true
            ]
            logger?("SecItemCopyMatching: \(query)")
            let status = SecItemCopyMatching(query as CFDictionary, &matchResult)
            guard status == errSecSuccess else {
                throw Error.osStatus(message: "Could not read attributes for key", osStatus: status)
            }
            guard let attributes = matchResult as? [String:Any] else {
                throw Error.inconcistency(message: "Tried reading key attributes something went wrong. Expected dictionary, but received \(String(describing: matchResult)).")
            }
            return attributes
        }
    }
    
    public final class PublicKey: Key {
        
        private var cachedData: PublicKeyData? = nil
        
        public func data() throws -> PublicKeyData {
            if let data = cachedData {
                return data
            } else {
                let data = try queryData()
                cachedData = data
                return data
            }
        }
        
        private func queryData() throws -> PublicKeyData {
            let keyRaw: Data
            if #available(iOS 10.0, *) {
                keyRaw = try export()
            } else {
                keyRaw = try exportWithOldApi()
            }
            guard keyRaw.first == Constants.noCompression else {
                throw Error.inconcistency(message: "Tried reading public key bytes, but its headers says it is compressed and this library only handles uncompressed keys.")
            }
            return PublicKeyData(keyRaw)
        }
        
        @available(iOS 10.0, *)
        private func export() throws -> Data {
            var error : Unmanaged<CFError>?
            guard let raw = SecKeyCopyExternalRepresentation(underlying, &error) else {
                throw EllipticCurveKeyPair.Error.fromError(error?.takeRetainedValue(), message: "Tried reading public key bytes.")
            }
            return raw as Data
        }
        
        private func exportWithOldApi() throws -> Data {
            var matchResult: AnyObject? = nil
            let query: [String:Any] = [
                kSecClass as String: kSecClassKey,
                kSecValueRef as String: underlying,
                kSecReturnData as String: true
            ]
            logger?("SecItemCopyMatching: \(query)")
            let status = SecItemCopyMatching(query as CFDictionary, &matchResult)
            guard status == errSecSuccess else {
                throw Error.osStatus(message: "Could not generate keypair", osStatus: status)
            }
            guard let keyRaw = matchResult as? Data else {
                throw Error.inconcistency(message: "Tried reading public key bytes. Expected data, but received \(String(describing: matchResult)).")
            }
            return keyRaw
        }
    }
    
    public final class PrivateKey: Key {
        
        public private(set) var context: LAContext?
        
        internal init(_ underlying: SecKey, context: LAContext?) {
            super.init(underlying)
            self.context = context
        }
        
        public func isStoredOnSecureEnclave() throws -> Bool {
            let attribute = try self.attributes()[kSecAttrTokenID as String] as? String
            return attribute == (kSecAttrTokenIDSecureEnclave as String)
        }
    }
    
    public final class AccessControl {
        
        // E.g. kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        public let protection: CFTypeRef
        
        // E.g. [.userPresence, .privateKeyUsage]
        public let flags: SecAccessControlCreateFlags
        
        public init(protection: CFTypeRef, flags: SecAccessControlCreateFlags) {
            self.protection = protection
            self.flags = flags
        }
        
        public func underlying() throws -> SecAccessControl {
            if flags.contains(.privateKeyUsage) {
                let flagsWithOnlyPrivateKeyUsage: SecAccessControlCreateFlags = [.privateKeyUsage]
                guard flags != flagsWithOnlyPrivateKeyUsage else {
                    throw EllipticCurveKeyPair.Error.inconcistency(message: "Couldn't create access control flag. Keychain chokes if you try to create access control with only [.privateKeyUsage] on devices older than iOS 11 and macOS 10.13.x")
                }
            }
            
            var error: Unmanaged<CFError>?
            let result = SecAccessControlCreateWithFlags(kCFAllocatorDefault, protection, flags, &error)
            guard let accessControl = result else {
                throw EllipticCurveKeyPair.Error.fromError(error?.takeRetainedValue(), message: "Tried creating access control object with flags \(flags) and protection \(protection)")
            }
            return accessControl
        }
    }
    
    public enum Error: LocalizedError {
        
        case underlying(message: String, error: NSError)
        case inconcistency(message: String)
        case authentication(error: LAError)
        
        public var errorDescription: String? {
            switch self {
            case let .underlying(message: message, error: error):
                return "\(message) \(error.localizedDescription)"
            case let .authentication(error: error):
                return "Authentication failed. \(error.localizedDescription)"
            case let .inconcistency(message: message):
                return "Inconcistency in setup, configuration or keychain. \(message)"
            }
        }
        
        internal static func osStatus(message: String, osStatus: OSStatus) -> Error {
            let error = NSError(domain: NSOSStatusErrorDomain, code: Int(osStatus), userInfo: [
                NSLocalizedDescriptionKey: message,
                NSLocalizedRecoverySuggestionErrorKey: "See https://www.osstatus.com/search/results?platform=all&framework=all&search=\(osStatus)"
                ])
            return .underlying(message: message, error: error)
        }
        
        internal static func probablyAuthenticationError(underlying: NSError) -> Error {
            return Error.authentication(error: .init(_nsError: NSError(domain: LAErrorDomain, code: LAError.authenticationFailed.rawValue, userInfo: [
                NSLocalizedFailureReasonErrorKey: "Found public key, but couldn't find or access private key. The errSecItemNotFound error is sometimes wrongfully reported when LAContext authentication fails",
                NSUnderlyingErrorKey: underlying
                ])))
        }
        
        internal static func fromError(_ error: CFError?, message: String) -> Error {
            let any = error as Any
            if let authenticationError = any as? LAError {
                return .authentication(error: authenticationError)
            }
            if let error = error,
                let domain = CFErrorGetDomain(error) as String? {
                let code = Int(CFErrorGetCode(error))
                var userInfo = (CFErrorCopyUserInfo(error) as? [String:Any]) ?? [String:Any]()
                if userInfo[NSLocalizedRecoverySuggestionErrorKey] == nil {
                    userInfo[NSLocalizedRecoverySuggestionErrorKey] = "See https://www.osstatus.com/search/results?platform=all&framework=all&search=\(code)"
                }
                let underlying = NSError(domain: domain, code: code, userInfo: userInfo)
                return .underlying(message: message, error: underlying)
            }
            return .inconcistency(message: "\(message) Unknown error occured.")
        }
        
    }
    
    @available(iOS 10.0, *)
    public enum Hash: String {
        
        case sha1
        case sha224
        case sha256
        case sha384
        case sha512
        
        @available(iOS 10.0, *)
        var signatureMessage: SecKeyAlgorithm {
            switch self {
            case .sha1:
                return SecKeyAlgorithm.ecdsaSignatureMessageX962SHA1
            case .sha224:
                return SecKeyAlgorithm.ecdsaSignatureMessageX962SHA224
            case .sha256:
                return SecKeyAlgorithm.ecdsaSignatureMessageX962SHA256
            case .sha384:
                return SecKeyAlgorithm.ecdsaSignatureMessageX962SHA384
            case .sha512:
                return SecKeyAlgorithm.ecdsaSignatureMessageX962SHA512
            }
        }
        
        @available(iOS 10.0, *)
        var encryptionEciesEcdh: SecKeyAlgorithm {
            switch self {
            case .sha1:
                return SecKeyAlgorithm.eciesEncryptionStandardX963SHA1AESGCM
            case .sha224:
                return SecKeyAlgorithm.eciesEncryptionStandardX963SHA224AESGCM
            case .sha256:
                return SecKeyAlgorithm.eciesEncryptionStandardX963SHA256AESGCM
            case .sha384:
                return SecKeyAlgorithm.eciesEncryptionStandardX963SHA384AESGCM
            case .sha512:
                return SecKeyAlgorithm.eciesEncryptionStandardX963SHA512AESGCM
            }
        }
    }
    
    public enum Token {
        case secureEnclave
        case keychain
        
        public static var secureEnclaveIfAvailable: Token {
            return Device.hasSecureEnclave ? .secureEnclave : .keychain
        }
    }
    
    public enum Device {
        
        public static var hasTouchID: Bool {
            if #available(OSX 10.12.2, *) {
                return LAContext().canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
            } else {
                return false
            }
        }
        
        public static var isSimulator: Bool {
            return TARGET_OS_SIMULATOR != 0
        }
        
        public static var hasSecureEnclave: Bool {
            return hasTouchID && !isSimulator
        }
        
    }
}
import Foundation

public extension Data {
    func sha256() -> Data {
        let bytes: Array<UInt8> = Array(self)
        let result = SHA256(bytes).calculate32()
        return Data(bytes: result)
    }
}

final public class SHA256 {
    
    let message: Array<UInt8>

    init(_ message: Array<UInt8>) {
        self.message = message
    }
    
    func calculate32() -> Array<UInt8> {
        var tmpMessage = bitPadding(to: self.message, blockSize: 64, allowance: 64 / 8)

        // hash values
        var hh = Array<UInt32>()
        h.forEach {(h) -> () in
            hh.append(UInt32(h))
        }

        // append message length, in a 64-bit big-endian integer. So now the message length is a multiple of 512 bits.
        tmpMessage += arrayOfBytes(value: message.count * 8, length: 64 / 8)

        // Process the message in successive 512-bit chunks:
        let chunkSizeBytes = 512 / 8 // 64
        for chunk in BytesSequence(chunkSize: chunkSizeBytes, data: tmpMessage) {
            // break chunk into sixteen 32-bit words M[j], 0 ≤ j ≤ 15, big-endian
            // Extend the sixteen 32-bit words into sixty-four 32-bit words:
            var M = Array<UInt32>(repeating: 0, count: k.count)
            for x in 0..<M.count {
                switch x {
                case 0...15:
                    let start = chunk.startIndex + (x * MemoryLayout<UInt32>.size)
                    let end = start + MemoryLayout<UInt32>.size
                    let le = chunk[start..<end].toUInt32Array()[0]
                    M[x] = le.bigEndian
                    break
                default:
                    let s0 = rotateRight(M[x-15], by: 7) ^ rotateRight(M[x-15], by: 18) ^ (M[x-15] >> 3)
                    let s1 = rotateRight(M[x-2], by: 17) ^ rotateRight(M[x-2], by: 19) ^ (M[x-2] >> 10)
                    M[x] = M[x-16] &+ s0 &+ M[x-7] &+ s1
                    break
                }
            }

            var A = hh[0]
            var B = hh[1]
            var C = hh[2]
            var D = hh[3]
            var E = hh[4]
            var F = hh[5]
            var G = hh[6]
            var H = hh[7]

            // Main loop
            for j in 0..<k.count {
                let s0 = rotateRight(A, by: 2) ^ rotateRight(A, by: 13) ^ rotateRight(A, by: 22)
                let maj = (A & B) ^ (A & C) ^ (B & C)
                let t2 = s0 &+ maj
                let s1 = rotateRight(E, by: 6) ^ rotateRight(E, by: 11) ^ rotateRight(E, by: 25)
                let ch = (E & F) ^ ((~E) & G)
                let t1 = H &+ s1 &+ ch &+ UInt32(k[j]) &+ M[j]

                H = G
                G = F
                F = E
                E = D &+ t1
                D = C
                C = B
                B = A
                A = t1 &+ t2
            }

            hh[0] = (hh[0] &+ A)
            hh[1] = (hh[1] &+ B)
            hh[2] = (hh[2] &+ C)
            hh[3] = (hh[3] &+ D)
            hh[4] = (hh[4] &+ E)
            hh[5] = (hh[5] &+ F)
            hh[6] = (hh[6] &+ G)
            hh[7] = (hh[7] &+ H)
        }

        // Produce the final hash value (big-endian) as a 160 bit number:
        var result = Array<UInt8>()
        result.reserveCapacity(hh.count / 4)
        ArraySlice(hh).forEach {
            let item = $0.bigEndian
            let toAppend: [UInt8] = [UInt8(item & 0xff), UInt8((item >> 8) & 0xff), UInt8((item >> 16) & 0xff), UInt8((item >> 24) & 0xff)]
            result += toAppend
        }
        return result
    }
    
    private lazy var h: Array<UInt64> = {
        return [0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a, 0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19]
    }()
    
    private lazy var k: Array<UInt64> = {
        return [0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
                0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3, 0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
                0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc, 0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
                0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7, 0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
                0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13, 0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
                0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3, 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
                0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
                0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208, 0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2]
    }()
    
    private func rotateRight(_ value: UInt32, by: UInt32) -> UInt32 {
        return (value >> by) | (value << (32 - by))
    }
    
    private func arrayOfBytes<T>(value: T, length: Int? = nil) -> Array<UInt8> {
        let totalBytes = length ?? MemoryLayout<T>.size
        
        let valuePointer = UnsafeMutablePointer<T>.allocate(capacity: 1)
        valuePointer.pointee = value
        
        let bytesPointer = UnsafeMutablePointer<UInt8>(OpaquePointer(valuePointer))
        var bytes = Array<UInt8>(repeating: 0, count: totalBytes)
        for j in 0..<min(MemoryLayout<T>.size, totalBytes) {
            bytes[totalBytes - 1 - j] = (bytesPointer + j).pointee
        }
        
        valuePointer.deinitialize(count: 1)
        valuePointer.deallocate()
        
        return bytes
    }
}

internal extension Collection where Self.Iterator.Element == UInt8, Self.Index == Int {
    func toUInt32Array() -> Array<UInt32> {
        var result = Array<UInt32>()
        result.reserveCapacity(16)
        for idx in stride(from: self.startIndex, to: self.endIndex, by: MemoryLayout<UInt32>.size) {
            var val: UInt32 = 0
            val |= self.count > 3 ? UInt32(self[idx.advanced(by: 3)]) << 24 : 0
            val |= self.count > 2 ? UInt32(self[idx.advanced(by: 2)]) << 16 : 0
            val |= self.count > 1 ? UInt32(self[idx.advanced(by: 1)]) << 8  : 0
            val |= !self.isEmpty ? UInt32(self[idx]) : 0
            result.append(val)
        }
        
        return result
    }
}

internal func bitPadding(to data: Array<UInt8>, blockSize: Int, allowance: Int = 0) -> Array<UInt8> {
    var tmp = data
    
    // Step 1. Append Padding Bits
    tmp.append(0x80) // append one bit (UInt8 with one bit) to message
    
    // append "0" bit until message length in bits ≡ 448 (mod 512)
    var msgLength = tmp.count
    var counter = 0
    
    while msgLength % blockSize != (blockSize - allowance) {
        counter += 1
        msgLength += 1
    }
    
    tmp += Array<UInt8>(repeating: 0, count: counter)
    return tmp
}

internal struct BytesSequence<D: RandomAccessCollection>: Sequence where D.Iterator.Element == UInt8,
    D.IndexDistance == Int,
    D.SubSequence.IndexDistance == Int,
D.Index == Int {
    let chunkSize: D.IndexDistance
    let data: D
    
    func makeIterator() -> AnyIterator<D.SubSequence> {
        var offset = data.startIndex
        return AnyIterator {
            let end = Swift.min(self.chunkSize, self.data.count - offset)
            let result = self.data[offset..<offset + end]
            offset = offset.advanced(by: result.count)
            if !result.isEmpty {
                return result
            }
            return nil
        }
    }
}
