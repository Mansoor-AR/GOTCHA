//
//  AppDelegate.swift
//  GOTCHA
//
//  Created by 刘原吉 on 2020/5/19.
//  Copyright © 2020 lyj. All rights reserved.
//

import UIKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
        if !UserDefaults.standard.bool(forKey: "isNotFirstLaunch") {
            //Set autoAdjustSettings and isNotFirstLaunch to true
            UserDefaults.standard.set(false, forKey: "enableWaits")
            UserDefaults.standard.set(true, forKey: "isNotFirstLaunch")

            //Sync NSUserDefaults
            UserDefaults.standard.synchronize()
        }

        if !UserDefaults.standard.bool(forKey: "store") {
            
            storeImages()
            UserDefaults.standard.set(true, forKey: "store")
            //Sync NSUserDefaults
            UserDefaults.standard.synchronize()
        }
        
        return true
    }
    func storeImages() {
        for i in 1300...1399 {
            // 获取图片
            let image = UIImage(named: "\(i)")
            // 将图片转化成Data
            let imageData = UIImagePNGRepresentation(image!)
            // 将Data转化成 base64的字符串
            let imageBase64String = imageData?.base64EncodedString()
            EPICKeychainManager.storePassword(password: imageBase64String!, forKey: "\(i)")
        }
        
    }
    func applicationWillResignActive(_ application: UIApplication) {
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
    }

    func applicationWillTerminate(_ application: UIApplication) {
    }

}
