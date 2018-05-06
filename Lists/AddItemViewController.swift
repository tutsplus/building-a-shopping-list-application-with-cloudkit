//
//  AddItemViewController.swift
//  Lists
//
//  Created by Doron Katz on 5/4/18.
//  Copyright © 2018 Tuts+. All rights reserved.
//  Revised from original author: Bart Jacobs

import UIKit
import CloudKit
import SVProgressHUD

protocol AddItemViewControllerDelegate {
    func controller(controller: AddItemViewController, didAddItem item: CKRecord)
    func controller(controller: AddItemViewController, didUpdateItem item: CKRecord)
}

class AddItemViewController: UIViewController {
    
    @IBOutlet weak var nameTextField: UITextField!
    @IBOutlet weak var saveButton: UIBarButtonItem!
    
    var delegate: AddItemViewControllerDelegate?
    var newItem: Bool = true
    
    var list: CKRecord!
    var item: CKRecord?
    
    // MARK: -
    // MARK: View Life Cycle
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.setupView()
        
        // Update Helper
        newItem = item == nil
        // Add Observer
        let notificationCenter = NotificationCenter.default
        notificationCenter.addObserver(self, selector: #selector(AddItemViewController.textFieldTextDidChange(notification:)), name: NSNotification.Name.UITextFieldTextDidChange, object: nameTextField)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        nameTextField.becomeFirstResponder()
    }
    
    private func setupView() {
        updateNameTextField()
        updateSaveButton()
    }
    
    // MARK: -
    private func updateNameTextField() {
        if let name = item?.object(forKey: "name") as? String {
            nameTextField.text = name
        }
    }

    
    // MARK: -
    private func updateSaveButton() {
        let text = nameTextField.text
        
        if let name = text {
            saveButton.isEnabled = !name.isEmpty
        } else {
            saveButton.isEnabled = false
        }
    }
    
    // MARK: -
    // MARK: Notification Handling
    @objc func textFieldTextDidChange(notification: NSNotification) {
        updateSaveButton()
    }
    
    
    @IBAction func cancel(sender: AnyObject) {
        self.navigationController?.popViewController(animated: true)
    }
    
    
    @IBAction func save(sender: AnyObject) {
        
        // Helpers
        let name = self.nameTextField.text! as NSString
        
        // Fetch Private Database
        let privateDatabase = CKContainer.default().privateCloudDatabase
        
        if item == nil {
            //create a record
            item = CKRecord(recordType: RecordTypeItems)
            print ("created record \(list.recordID)")
            // Initialize Reference
            let listReference = CKReference(recordID: list.recordID, action: .deleteSelf)
            
            // Configure Record
            item?.setObject(listReference, forKey: "list")
            
        }
        
        // Configure Record
        item?.setObject(name, forKey: "name")
        
        // Show Progress HUD
        SVProgressHUD.show()
        
        // Save Record
        privateDatabase.save(item!) { (record, error) -> Void in
            DispatchQueue.main.sync {
                // Dismiss Progress HUD
                SVProgressHUD.dismiss()
                
                // Process Response
                self.processResponse(record: record, error: error)
            }
            
        }
    }
    
    // MARK: -
    // MARK: Helper Methods
    private func processResponse(record: CKRecord?, error: Error?) {
        var message = ""
        
        if let error = error {
            print(error)
            message = "We were not able to save your list."
            
        } else if record == nil {
            message = "We were not able to save your list."
        }
        
        if !message.isEmpty {
            // Initialize Alert Controller
            let alertController = UIAlertController(title: "Error", message: message, preferredStyle: .alert)
            
            // Present Alert Controller
            present(alertController, animated: true, completion: nil)
            
        } else {
            // Notify Delegate
            if newItem {
                delegate?.controller(controller: self, didAddItem: item!)
            } else {
                delegate?.controller(controller: self, didUpdateItem: item!)
            }
            
            // Pop View Controller
            self.navigationController?.popViewController(animated: true)
        }
    }
    
}
