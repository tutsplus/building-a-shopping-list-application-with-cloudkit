//
//  ViewController.swift
//  List
//
//  Created by Doron Katz on 4/23/18.
//  Copyright © 2018 Tuts+. All rights reserved.
//  Revised from original author: Bart Jacobs

import UIKit
import CloudKit
import SVProgressHUD

let SegueItemDetail = "ItemDetail"

class ListViewController: UIViewController, UITableViewDelegate, UITableViewDataSource{
    static let ItemCell = "ItemCell"
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var messageLabel: UILabel!
    @IBOutlet weak var activityIndicatorView: UIActivityIndicatorView!
    
    var list: CKRecord!
    var items = [CKRecord]()
    
    var selection: Int?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = self.list.object(forKey: "name") as? String
        setupView()
        fetchItems()
    }
    
    
    private func updateView(){
        let hasRecords = self.items.count > 0
        
        self.tableView.isHidden = !hasRecords
        messageLabel.isHidden = hasRecords
        activityIndicatorView.stopAnimating()
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
}

// MARK: -
// MARK: UITableView Delegate Methods
extension ListViewController{
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.items.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        // Dequeue Reusable Cell
        let cell = tableView.dequeueReusableCell(withIdentifier: ListViewController.ItemCell, for: indexPath)
        
        // Configure Cell
        cell.accessoryType = .detailDisclosureButton
        
        // Fetch Record
        let item = items[indexPath.row]
        
        if let itemName = item.object(forKey: "name") as? String {
            // Configure Cell
            cell.textLabel?.text = itemName
            
        } else {
            cell.textLabel?.text = "-"
        }
        
        if let itemNumber = item.object(forKey: "number") as? Int {
            // Configure Cell
            cell.detailTextLabel?.text = "\(itemNumber)"
            
        } else {
            cell.detailTextLabel?.text = "1"
        }
        
        return cell
    }
    
    func tableView(tableView: UITableView, canEditRowAtIndexPath indexPath: NSIndexPath) -> Bool {
        return true
    }
    
    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
        
        guard editingStyle == .delete else { return }
        
        // Fetch Record
        let item = items[indexPath.row]
        
        // Delete Record
        deleteRecord(item)
    }
    
    
    func tableView(tableView: UITableView, accessoryButtonTappedForRowWithIndexPath indexPath: NSIndexPath) {
        tableView.deselectRow(at: indexPath as IndexPath, animated: true)
        
        // Save Selection
        selection = indexPath.row
        
        // Perform Segue
        performSegue(withIdentifier: SegueItemDetail, sender: self)
    }

    
    
    private func deleteRecord(_ list: CKRecord) {
        // Fetch Private Database
        let privateDatabase = CKContainer.default().privateCloudDatabase
        
        // Show Progress HUD
        SVProgressHUD.show()
        
        // Delete List
        privateDatabase.delete(withRecordID: list.recordID) { (recordID, error) -> Void in
            DispatchQueue.main.sync {
                SVProgressHUD.dismiss()
                
                // Process Response
                self.processResponseForDeleteRequest(list, recordID: recordID, error: error)
            }
        }
    }
    
    private func processResponseForDeleteRequest(_ record: CKRecord, recordID: CKRecordID?, error: Error?) {
        var message = ""
        
        if let error = error {
            print(error)
            message = "We are unable to delete the list."
            
        } else if recordID == nil {
            message = "We are unable to delete the list."
        }
        
        if message.isEmpty {
            // Calculate Row Index
            
            let index = self.items.index(of: record)
            
            if let index = index {
                // Update Data Source
                self.items.remove(at: index)
                
                if items.count > 0 {
                    // Update Table View
                    self.tableView.deleteRows(at: [NSIndexPath(row: index, section: 0) as IndexPath], with: .right)
                    
                } else {
                    // Update Message Label
                    messageLabel.text = "No Records Found"
                    
                    // Update View
                    updateView()
                }
            }
            
        } else {
            // Initialize Alert Controller
            let alertController = UIAlertController(title: "Error", message: message, preferredStyle: .alert)
            
            // Present Alert Controller
            present(alertController, animated: true, completion: nil)
        }
    }
    
    func tableView(_ tableView: UITableView, accessoryButtonTappedForRowWith indexPath: IndexPath) {
        
        tableView.deselectRow(at: indexPath as IndexPath, animated: true)
        
        // Save Selection
        selection = indexPath.row
        
        // Perform Segue
        performSegue(withIdentifier: "ListDetail", sender: self)
    }
    
    // MARK: -
    // MARK: Segue Life Cycle
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        
        guard let identifier = segue.identifier else { return }
        
        switch identifier {
        case SegueItemDetail:
            // Fetch Destination View Controller
            let addItemViewController = segue.destination as! AddItemViewController
            
            // Configure View Controller
            addItemViewController.list = list
            addItemViewController.delegate = self
            
            if let selection = self.selection {
                // Fetch Item
                let item = items[selection]
                
                // Configure View Controller
                addItemViewController.item = item
            }
        default:
            break
        }
    }
    
}

// MARK: -
// MARK: View Methods
extension ListViewController{
    private func setupView(){
        tableView.isHidden = true
        messageLabel.isHidden = true
        activityIndicatorView.startAnimating()
    }
}

// MARK: -
// MARK: AddItemViewControllerDelegate methods
extension ListViewController: AddItemViewControllerDelegate{
    func controller(controller: AddItemViewController, didAddItem item: CKRecord) {
        // Add items
        items.append(item)
        
        // Sort Items
        sortItems()
        
        // Update Table View
        tableView.reloadData()
        
        // Update View
        updateView()
    }
    
    func controller(controller: AddItemViewController, didUpdateItem item: CKRecord) {
        // Sort Items
        sortItems()
        
        // Update Table View
        tableView.reloadData()
    }
    
    // MARK: -
    // MARK: Helper Methods
    private func fetchItems() {
        // Fetch Private Database
        let privateDatabase = CKContainer.default().privateCloudDatabase
        
        // Initialize Query
        let reference = CKReference(recordID: list.recordID, action: .deleteSelf)
        let query = CKQuery(recordType: RecordTypeItems, predicate: NSPredicate(format: "list == %@", reference))
        
        // Configure Query
        query.sortDescriptors = [NSSortDescriptor(key: "name", ascending: true)]
        
        // Perform Query
        privateDatabase.perform(query, inZoneWith: nil) { (records, error) -> Void in
            DispatchQueue.main.sync {
                self.processResponseForQuery(records, error: error)
            }
        }
    }
    
    private func processResponseForQuery(_ records: [CKRecord]?, error: Error?) {
        var message = ""
        
        if let error = error {
            print(error)
            message = "Error Fetching Items for List"
            
        } else if let records = records {
            items = records
            
            if items.count == 0 {
                message = "No Items Found"
            }
            
        } else {
            message = "No Items Found"
        }
        
        if message.isEmpty {
            tableView.reloadData()
        } else {
            messageLabel.text = message
        }
        
        updateView()
    }
    
    
    private func sortItems() {
        self.items.sort {
            var result = false
            let name0 = $0.object(forKey: "name") as? String
            let name1 = $1.object(forKey: "name") as? String
            
            if let listName0 = name0, let listName1 = name1 {
                result = listName0.localizedCaseInsensitiveCompare(listName1) == .orderedAscending
            }
            
            return result
        }
    }
}
