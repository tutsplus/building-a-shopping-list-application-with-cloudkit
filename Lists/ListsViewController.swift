//
//  ViewController.swift
//  Lists
//
//  Created by Doron Katz on 4/23/18.
//  Copyright © 2018 Tuts+. All rights reserved.
//

import UIKit
import CloudKit
import SVProgressHUD

class ListsViewController: UIViewController, UITableViewDelegate, UITableViewDataSource{
    static let ListCell = "ListCell"
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var messageLabel: UILabel!
    @IBOutlet weak var activityIndicatorView: UIActivityIndicatorView!
    
    var lists = [CKRecord]()
    var selection: Int?

    override func viewDidLoad() {
        super.viewDidLoad()
        setupView()
        self.messageLabel.text = "Loading records"
        fetchLists()
    }
    
    private func fetchUserRecordID() {
        // Fetch Default Container
        let defaultContainer = CKContainer.default()
        
        // Fetch User Record
        defaultContainer.fetchUserRecordID { (recordID, error) -> Void in
            if let responseError = error {
                print(responseError)
                
            } else if let userRecordID = recordID {
                DispatchQueue.main.sync {
                    self.fetchUserRecord(recordID: userRecordID)
                }
            }
        }
        
    }
    
    private func updateView(){
        let hasRecords = self.lists.count > 0
        
        self.tableView.isHidden = !hasRecords
        messageLabel.isHidden = hasRecords
        activityIndicatorView.stopAnimating()
    }

    private func fetchLists() {
        // Fetch Private Database
        let privateDatabase = CKContainer.default().privateCloudDatabase
        
        // Initialize Query
        let query = CKQuery(recordType: "Lists", predicate: NSPredicate(value: true))
        
        // Configure Query
        query.sortDescriptors = [NSSortDescriptor(key: "name", ascending: true)]
        
        // Perform Query
        privateDatabase.perform(query, inZoneWith: nil) { (records, error) in
            records?.forEach({ (record) in
                
                guard error == nil else{
                    print(error?.localizedDescription as Any)
                    return
                }
                
                print(record.value(forKey: "name") ?? "")
                self.lists.append(record)
                DispatchQueue.main.sync {
                    self.tableView.reloadData()
                    self.messageLabel.text = ""
                    self.updateView()
                }
            })

        }
    }
    
    
    
    private func fetchUserRecord(recordID: CKRecordID) {
        // Fetch Default Container
        let defaultContainer = CKContainer.default()
        
        // Fetch Private Database
        let privateDatabase = defaultContainer.privateCloudDatabase
        
        // Fetch User Record
        privateDatabase.fetch(withRecordID: recordID) { (record, error) -> Void in
            if let responseError = error {
                print(responseError)
                
            } else if let userRecord = record {
                print(userRecord)
            }
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

}

// MARK: -
// MARK: UITableView Delegate Methods
extension ListsViewController{
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return lists.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        // Dequeue Reusable Cell
        let cell = tableView.dequeueReusableCell(withIdentifier: ListsViewController.ListCell, for: indexPath)
        
        // Configure Cell
        cell.accessoryType = .detailDisclosureButton
        
        // Fetch Record
        let list = lists[indexPath.row]
        
        if let listName = list.object(forKey: "name") as? String {
            // Configure Cell
            cell.textLabel?.text = listName
            
        } else {
            cell.textLabel?.text = "-"
        }
        
        return cell
    }

    func tableView(tableView: UITableView, canEditRowAtIndexPath indexPath: NSIndexPath) -> Bool {
        return true
    }
    
    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
        
        guard editingStyle == .delete else { return }
        
        // Fetch Record
        let list = lists[indexPath.row]
        
        // Delete Record
        deleteRecord(list)
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
            let index = self.lists.index(of: record)
            
            if let index = index {
                // Update Data Source
                self.lists.remove(at: index)
                
                if lists.count > 0 {
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
        
        // Fetch Destination View Controller
        let addListViewController = segue.destination as! AddListViewController
        
        // Configure View Controller
        addListViewController.delegate = self
        
        if let selection = selection {
            // Fetch List
            let list = lists[selection]
            
            // Configure View Controller
            addListViewController.list = list
        }
    }

}

// MARK: -
// MARK: View Methods
extension ListsViewController{
    private func setupView(){
        tableView.isHidden = true
        messageLabel.isHidden = true
        activityIndicatorView.startAnimating()
    }
}

// MARK: -
// MARK: AddListViewControllerDelegate methods
extension ListsViewController: AddListViewControllerDelegate{
    func controller(controller: AddListViewController, didAddList list: CKRecord) {
        // Add List to Lists
        lists.append(list)
        
        // Sort Lists
        sortLists()
        
        // Update Table View
        tableView.reloadData()
        
        // Update View
        updateView()
    }
    
    func controller(controller: AddListViewController, didUpdateList list: CKRecord) {
        sortLists()
        
        // Update Table View
        tableView.reloadData()
    }

    
    private func sortLists() {
        self.lists.sort {
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
