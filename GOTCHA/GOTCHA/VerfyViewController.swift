//
//  VerfyViewController.swift
//  SimpleCalculator
//
//  Created by 刘原吉 on 2/20/20.
//  Copyright © 2020 Alex Ilyenko. All rights reserved.
//

import UIKit

class VerfyViewController: UIViewController {

    
    var bgView: UIView!
    var numberString: String = ""
    var timer: Timer?
    
    var vertfyView: VertfyView!
    //错误次数
    var wrongNum = 0
    //执行总时间
    var totalTime = 0
    override func viewDidLoad() {
        super.viewDidLoad()

        showVertyView()
    }
    
    func getUIImage() -> UIImage{
        //图片的数字
        let name = arc4random() % 99 + 1300
        self.numberString = "\(name)"
        let imageStr = EPICKeychainManager.passwordForKey(key: "\(name)")
        
        let imageData2 = Data(base64Encoded: imageStr!)

        // 将Data转化成图片
        let image2 = UIImage(data: imageData2!)
        
        return image2!
    }
    func updateUIImage() -> UIImage{
        let name = arc4random() % 99 + 1300
        if "\(name)" == self.numberString {
            _ = updateUIImage()
        }
        self.numberString = "\(name)"
        let imageStr = EPICKeychainManager.passwordForKey(key: "\(name)")
        
        let imageData2 = Data(base64Encoded: imageStr!)

        // 将Data转化成图片
        let image2 = UIImage(data: imageData2!)
        
        return image2!
    }
    func showVertyView() {
        let window = UIApplication.shared.keyWindow!
        
        vertfyView = VertfyView(frame: CGRect(x: 0, y: 100, width: SCREENWIDTH, height: 240))
        vertfyView.imageV.image = getUIImage()
        vertfyView.delegate = self
        bgView = UIView(frame: window.bounds)
        bgView.backgroundColor = UIColor(white: 0, alpha: 0.7)
        bgView.addSubview(vertfyView)
        window.addSubview(bgView)
        
//        let tap = UITapGestureRecognizer(target: self, action: #selector(hide))
//        bgView.addGestureRecognizer(tap)
    }

    @objc func hide() {
        bgView.removeFromSuperview()
    }
}
//点击确认时
extension VerfyViewController: VertfyViewDelegate {
    func vertyCodeWith(_ code: String?) {
        if let code = code {
            if code.count == 4 && code == self.numberString{
                showInfo(message: "Success")
            }
            self.wrongNum += 1
            if self.wrongNum > 3 {
                self.wrongNum = 3
            }
            createTimer()
            self.isShowWrongInfo()

        }
    }
    //开启定时器
    func createTimer() {
        if self.timer == nil {
            timer = Timer.scheduledTimer(timeInterval:1, target:self, selector:#selector(stickDown), userInfo:nil, repeats:true)
        }
    }
    @objc func stickDown() {
        self.totalTime += 1
        print(self.totalTime)
        if  self.wrongNum == 3 && self.totalTime > 180 {
            self.totalTime = 0
            self.wrongNum = 0
            vertfyView.setButtonAbled()
            vertfyView.imageV.image = updateUIImage()
            self.timer?.invalidate()
            self.timer = nil
        }
    }
    //是否提示错误次数达到3次的提示
    func isShowWrongInfo(){
        if self.wrongNum < 3 {
            showInfo(message: "Failure")
        }
        if self.totalTime <= 60 && self.wrongNum == 3 || (self.totalTime > 60 && self.totalTime < 180  &&
         self.totalTime <= 60 && self.wrongNum == 3){
            vertfyView.setButtonDisabled()
            self.showInfo(message: "Sorry, you are not allowed to enter the CAPTCHA, please try again later.")
        }
    }
    
}
