//
//  ImageViewController.swift
//  SimpleCalculator
//
//  Created by 刘原吉 on 1/7/20.
//  Copyright © 2020 Alex Ilyenko. All rights reserved.
//

import UIKit
let SCREENWIDTH = UIScreen.main.bounds.size.width
let SCREENHEIGHT = UIScreen.main.bounds.size.height

class ImageViewController: UIViewController {

    var collectionView: UICollectionView!
    var button: UIButton!
    
    var selectedIndex = [String]()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.title = "IMAGES"
//        initUI()
        getStoreImages()
    }
    func getStoreImages() {
        if let imagesStrs = EPICKeychainManager.passwordForKey(key: "images") {
            let array = imagesStrs.components(separatedBy: "/")
            selectedIndex = array
            self.title = "SAVED IMAGES"
        }
        initUI()
    }
    func initUI() {
        let width = (SCREENWIDTH-25) / 4
        let layout = UICollectionViewFlowLayout.init()
        layout.itemSize = CGSize(width: width, height: width)
        layout.minimumLineSpacing = 5
        layout.minimumInteritemSpacing = 5
        layout.scrollDirection = .vertical
        layout.sectionInset = UIEdgeInsets.init(top: 5, left: 5, bottom: 5, right: 5)
        
        collectionView = UICollectionView.init(frame: CGRect(x:0, y:64, width:SCREENWIDTH, height:self.view.frame.size.height), collectionViewLayout: layout)
        collectionView?.backgroundColor = UIColor.gray
        collectionView?.delegate = self
        collectionView?.dataSource = self
        self.view.addSubview(collectionView!)
        
        collectionView?.register(UINib.init(nibName: "CollectionViewCell", bundle: nil), forCellWithReuseIdentifier: "cell")
        
        button = UIButton(frame: CGRect(x: SCREENWIDTH / 2 - 30, y: SCREENHEIGHT-130, width: 100, height: 40))
        button.setTitle("SAVE", for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.backgroundColor = .blue
        button.isHidden = true
        button.addTarget(self, action: #selector(btnClick(_ :)), for: .touchUpInside)
        self.view.addSubview(button)
        
        
    }
    
    //save
    @objc func btnClick(_ sender: UIButton) {
        let savedStr = selectedIndex.joined(separator: "/")
        let _ = EPICKeychainManager.storePassword(password: savedStr, forKey: "images")
        self.showInfo(message: "Store Success!")
    }
    @IBAction func removed(_ sender: UIBarButtonItem) {
        let _ = EPICKeychainManager.removePasswordForKey(key: "images")
        getStoreImages()
        self.title = "IMAGES"
        selectedIndex.removeAll()
        self.collectionView.reloadData()
    }
    
}

extension ImageViewController: UICollectionViewDataSource, UICollectionViewDelegate {
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return selectedIndex.count == 0 ? 100 : selectedIndex.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell:CollectionViewCell = collectionView.dequeueReusableCell(withReuseIdentifier: "cell", for: indexPath) as! CollectionViewCell
        cell.backgroundColor = .white
//        let index = indexPath.row + 1
//        cell.imageView.image = UIImage(named: selectedIndex[indexPath.row])
        
        if selectedIndex.count == 0 {
            cell.imageView.image = UIImage(named: "\(indexPath.row)")
            cell.selectedBtn.tag = 100 + indexPath.row
        } else {
            let index = Int(selectedIndex[indexPath.row])! - 100
            cell.imageView.image = UIImage(named: "\(index)")
        }
        return cell
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let index = indexPath.row + 100
        selecteOrUnSelectedBtn(index: index)
    }
    
    private func selecteOrUnSelectedBtn(index: Int) {
        if (EPICKeychainManager.passwordForKey(key: "images") == nil) {
            let btn = self.collectionView.viewWithTag(index) as! UIButton
            btn.isHidden = !btn.isHidden
            
            if btn.isHidden {
                selectedIndex = selectedIndex.filter {$0 != "\(index)"}
            } else {
                selectedIndex.append("\(index)")
            }
            self.button.isHidden = selectedIndex.count <= 0
        }

    }
}
