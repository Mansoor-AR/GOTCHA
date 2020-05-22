//
//  CollectionViewCell.swift
//  SimpleCalculator
//
//  Created by 刘原吉 on 1/7/20.
//  Copyright © 2020 Alex Ilyenko. All rights reserved.
//

import UIKit

class CollectionViewCell: UICollectionViewCell {

    @IBOutlet weak var imageView: UIImageView!
    
    @IBOutlet weak var selectedBtn: UIButton!
    override func awakeFromNib() {
        super.awakeFromNib()
    }

}
