//
//  VertfyView.swift
//  SimpleCalculator
//
//  Created by 刘原吉 on 2/20/20.
//  Copyright © 2020 Alex Ilyenko. All rights reserved.
//

import UIKit

protocol VertfyViewDelegate {
    func vertyCodeWith(_ code: String?)
}

class VertfyView: UIView {

    @IBOutlet weak var imageV: UIImageView!
    
    @IBOutlet weak var code: UITextField!
    @IBOutlet weak var confirmBtn: UIButton!
    
    var  delegate: VertfyViewDelegate?
       //布局相关设置
       override func layoutSubviews() {
           super.layoutSubviews()
       }
        
       /*** 下面的几个方法都是为了让这个自定义类能将xib里的view加载进来。这个是通用的，我们不需修改。 ****/
       var contentView:UIView!
        
       //初始化时将xib中的view添加进来
       override init(frame: CGRect) {
           super.init(frame: frame)
           contentView = loadViewFromNib()
           addSubview(contentView)
           addConstraints()
       }
        
        //初始化时将xib中的view添加进来
       required init?(coder aDecoder: NSCoder) {
           super.init(coder: aDecoder)
           contentView = loadViewFromNib()
           addSubview(contentView)
           addConstraints()
       }
       //加载xib
       func loadViewFromNib() -> UIView {
           let className = type(of: self)
           let bundle = Bundle(for: className)
           let name = NSStringFromClass(className).components(separatedBy: ".").last
           let nib = UINib(nibName: name!, bundle: bundle)
           let view = nib.instantiate(withOwner: self, options: nil).first as! UIView
           return view
       }
    @IBAction func verttyCode(_ sender: UIButton) {
        self.delegate?.vertyCodeWith(self.code.text)
    }
    //设置好xib视图约束
       func addConstraints() {
           contentView.translatesAutoresizingMaskIntoConstraints = false
           var constraint = NSLayoutConstraint(item: contentView, attribute: .leading,
                                       relatedBy: .equal, toItem: self, attribute: .leading,
                                       multiplier: 1, constant: 0)
           addConstraint(constraint)
           constraint = NSLayoutConstraint(item: contentView, attribute: .trailing,
                                           relatedBy: .equal, toItem: self, attribute: .trailing,
                                           multiplier: 1, constant: 0)
           addConstraint(constraint)
           constraint = NSLayoutConstraint(item: contentView, attribute: .top, relatedBy: .equal,
                                           toItem: self, attribute: .top, multiplier: 1, constant: 0)
           addConstraint(constraint)
           constraint = NSLayoutConstraint(item: contentView, attribute: .bottom,
                                       relatedBy: .equal, toItem: self, attribute: .bottom,
                                       multiplier: 1, constant: 0)
           addConstraint(constraint)
       }
    //按钮失效
    func setButtonDisabled() {
        self.confirmBtn.isEnabled = false
    }
    //按钮生效
    func setButtonAbled() {
        self.confirmBtn.isEnabled = true
    }
}
