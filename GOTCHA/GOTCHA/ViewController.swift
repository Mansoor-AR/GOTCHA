//
//  ViewController.swift
//  GOTCHA
//
//  Created by 刘原吉 on 2020/5/19.
//  Copyright © 2020 lyj. All rights reserved.
//

import UIKit

class ViewController: UIViewController {

    static var isWaitEnabled: Bool! = false
    @IBOutlet weak var resultLabel: UILabel!
    private var firstNumber: Double = 0.0
    private var symbol: String = ""
    private var isSymbolPressed: Bool = false
    var settings: SettingsViewController!

    var keys:[String] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    @IBAction func pressNumber(_ sender: UIButton) {
        let buttonText = sender.titleLabel?.text!
        let labelText = resultLabel.text!
        if buttonText == "." && labelText.contains(".") {
            return
        }
        if isSymbolPressed {
            resultLabel.text = buttonText
            isSymbolPressed = false
            return
        }
        resultLabel.text =
                "\((Double(labelText) != 0.0 || labelText.contains(".") || buttonText == ".") ? labelText : "")" +
                        "\(buttonText!)"
    }

    @IBAction func pressSymbol(_ sender: UIButton) {
        firstNumber = Double(resultLabel.text!)!
        symbol = (sender.titleLabel?.text)!
        isSymbolPressed = true
    }

    @IBAction func pressReset(_ sender: UIButton) {
        wait()
        resultLabel.text = String(0)
        firstNumber = 0.0
        symbol = ""
        isSymbolPressed = false
    }

    @IBAction func pressCalculate(_ sender: UIButton) {
        let secondNumber = Double(resultLabel.text!)!
        let result = calculate(secondNumber)
        wait()
        resultLabel.text = String(result)
        firstNumber = 0.0
        symbol = ""
        isSymbolPressed = true
    }

    private func calculate(_ secondNumber: Double) -> Double {
        switch symbol {
        case "+": return firstNumber + secondNumber
        case "-": return firstNumber - secondNumber
        case "*": return firstNumber * secondNumber
        case "/": return firstNumber / secondNumber
        default: return Double(resultLabel.text!)!
        }
    }

    private func wait() {
        if UserDefaults.standard.bool(forKey: "enableWaits") {
            sleep(2)
        }
    }
    
    @IBAction func storeClick(_ sender: UIBarButtonItem) {
        
        if  let text = self.resultLabel.text {
            self.keys.append(text)
            let _ = EPICKeychainManager.storePassword(password: text, forKey: text)
            
        }
        self.showInfo(message: "Store Success!")
        
    }
    @IBAction func retrieveClick(_ sender: Any) {
        var result = "result = "
        for key in keys.unique {
            if var value = EPICKeychainManager.passwordForKey(key: key) {
                value += "\n"
                result += value
            }
         
        }
        
        self.showInfo(message: result)
    }
    

    
}
extension Array where Element:Hashable{
    var unique : [Element] {
        var keys:[Element:()] = [:]
        return filter{keys.updateValue((), forKey:$0) == nil}
    }
}

extension UIViewController {
    func showInfo(message:String) {
        let vc = UIAlertController(title: "Info", message: message, preferredStyle: .alert)
        let ac = UIAlertAction(title: "Ok", style: .cancel, handler: nil)
        vc.addAction(ac)
        self.present(vc, animated: true, completion: nil)
    }
}

