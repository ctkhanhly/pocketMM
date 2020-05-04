//
//  AlertPageController.swift
//  pocketMM
//
//  Created by Ly Cao on 4/26/20.
//  Copyright © 2020 NYU. All rights reserved.
//

import UIKit
import Firebase
import UserNotifications
import Foundation

class AlertPageController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    
    @IBOutlet var table: UITableView!
    var reminders = [reminder]()
    var user : User?
    var notificationGranted = false
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
         title = "💰Reminders and Alerts"
        UNUserNotificationCenter.current().requestAuthorization(
        options: [.alert,.sound]) {(granted, error) in
                self.notificationGranted = true
                if let error = error {
                    print("granted, but error in notif permissions:\(error.localizedDescription)")
                }
        }
   
 
        
         if let currentUser = user{
             reminders = currentUser.reminders
         }
         else{
            self.loadReminders()
        }
    
           
        table.delegate = self
        table.dataSource = self
        table.reloadData()
 
         
    }
    
    
  
    func loadReminders() {
        if let email = Auth.auth().currentUser?.email{
            db.collection(CONST.FSTORE.usersCollection).document(email).getDocument{
               (querySnapshot, error) in
                if let e = error{
                    print(e.localizedDescription)
                    return
                }
                if let jsonData = querySnapshot?.data(){
                    let decoder = JSONDecoder()
                    do{
                        let data = try JSONSerialization.data(withJSONObject: jsonData, options: JSONSerialization.WritingOptions.prettyPrinted)

                        let decodedData = try decoder.decode(Reminders.self, from: data)
                        
                        for reminder in decodedData.reminders {
                            allReminders.append(reminder)
                        }
                        print("all reminders ", allReminders)
                    }
                    catch{
                        print("error from parsing reminders json : ", error)
                      
                    }
                    
                }
            }
        }
    }
    
    
    override func viewDidAppear(_ animated: Bool){
        super.viewDidAppear(true)
        //table.reloadData()
    }
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return reminders.count
    }
    
/* !!TO FIX !! */
    func convertToDate(date: String)-> Date  {
        let isoDate = date
        print("date: \(isoDate)")
    
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        dateFormatter.calendar = Calendar(identifier: .gregorian)
        let xdate = dateFormatter.date(from: isoDate)
        print("xdate: \(xdate)")
        
        return xdate!
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cellIdentifier = "cell"
        let cell = tableView.dequeueReusableCell(withIdentifier: cellIdentifier, for: indexPath)
        let reminder = reminders[indexPath.row]
        cell.textLabel?.text = reminder.title
        print(reminder.date)
        //let date = self.convertToDate(date: reminder.date)
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM dd, YYYY"
        cell.detailTextLabel?.text = "Due: " + reminder.date
        
        //make due date red if overdue
        if NSDate().earlierDate(self.convertToDate(date: reminder.date)) == self.convertToDate(date: reminder.date) {
            cell.detailTextLabel?.textColor = UIColor.red
        }
        else if NSDate() as Date == self.convertToDate(date: reminder.date) {
            cell.detailTextLabel?.textColor = UIColor.red
        }
        else{
            cell.detailTextLabel?.textColor = UIColor.blue
          return cell
          
      }
        return cell
    }
    
    @IBAction func didTapAdd(){
        //show
        guard let addVC = storyboard?.instantiateViewController(withIdentifier: "add") as? AddReminderViewController else {
            return
        }
        
        addVC.title = "New Reminder"
        addVC.navigationItem.largeTitleDisplayMode = .never
        addVC.completion = {title, date, frequency, alert in
            DispatchQueue.main.async {
                self.navigationController?.popToViewController(self, animated: true)
                let newReminder = reminder(title: title, date: "\(date)", frequency: frequency, identifier: "id_\(title)")
                print("new reminder created")
                self.reminders.append(newReminder)
                self.table.reloadData()
                
                let content = UNMutableNotificationContent()
                content.title = title
                content.body = "pocketMM reminder"
                content.sound = .default
                
                //TODO ALERT PART
                
                let calendar = Calendar.current
                let targetDate = date
                
                var dateComponents = DateComponents()
                
                if frequency == "every month" {
                    dateComponents.day = calendar.component(.day, from: targetDate)
                }
                else if frequency == "every year" {
                    dateComponents.month = calendar.component(.month, from: targetDate)
                }
                else if frequency == "every week" {
                    dateComponents.weekday = calendar.component(.weekday, from: targetDate)
                }
                
                let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true )
                let request = UNNotificationRequest(identifier: "id_\(title)", content: content, trigger: trigger)
                
                UNUserNotificationCenter.current().add(request) { (error) in
                    if let error = error {
                        print("error")
                    }
                }
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
                self.saveReminders(title: title, dueDate: formatter.string(from: date), frequency: frequency)
                print("notification added: \(request.identifier)")
                    
                }
            }
        
        navigationController?.pushViewController(addVC, animated: true)
    }
    
    //save reminders to firebase
    func saveReminders(title: String, dueDate: String, frequency: String) {
        print("trying to save to firebase")
        let title = title
        let due_date = dueDate
        let frequency = frequency
        let email = Auth.auth().currentUser?.email
        let docData : [String: Any] = [
                  CONST.FSTORE.reminder_title : title,
                  CONST.FSTORE.reminder_due_date : due_date,
                  CONST.FSTORE.reminder_frequency : frequency
        ]

        db.collection(CONST.FSTORE.usersCollection).document(email!).updateData([
                  CONST.FSTORE.reminders : FieldValue.arrayUnion([docData])
              ])
          
      
    }
    
    //allow delete
    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            // Delete the row from the data source
            let toRemove = reminders.remove(at: indexPath.row)
            
            //TODO cancel local notification
            let center = UNUserNotificationCenter.current()
            
          //  center.removePendingNotificationRequests(withIdentifiers: [toRemove.identifier])
            tableView.deleteRows(at: [indexPath], with: .fade)
        }
    }
        
    @IBAction func logOutPressed(_ sender: UIBarButtonItem) {
        let firebaseAuth = Auth.auth()
        do {
          try firebaseAuth.signOut()
            navigationController?.popToRootViewController(animated: true)
        } catch let signOutError as NSError {
          print ("Error signing out: %@", signOutError)
        }
    }


    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath){
        tableView.deselectRow(at: indexPath, animated: true)
    }


  
}
    
    


