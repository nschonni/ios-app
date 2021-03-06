//
//  AntiTrackerViewController.swift
//  IVPNClient
//
//  Created by Juraj Hilje on 15/04/2019.
//  Copyright © 2019 IVPN. All rights reserved.
//

import UIKit
import ActiveLabel

class AntiTrackerViewController: UITableViewController {
    
    @IBOutlet weak var antiTrackerSwitch: UISwitch!
    @IBOutlet weak var antiTrackerHardcoreSwitch: UISwitch!
    
    @IBAction func toggleAntiTracker(_ sender: UISwitch) {
        if sender.isOn && Application.shared.settings.connectionProtocol.tunnelType() == .ipsec {
            showAlert(title: "IKEv2 not supported", message: "AntiTracker is supported only for OpenVPN and WireGuard protocols.") { _ in
                sender.setOn(false, animated: true)
            }
            return
        }
        
        UserDefaults.shared.set(sender.isOn, forKey: UserDefaults.Key.isAntiTracker)
        antiTrackerHardcoreSwitch.isEnabled = sender.isOn
    }
    
    @IBAction func toggleAntiTrackerHardcore(_ sender: UISwitch) {
        UserDefaults.shared.set(sender.isOn, forKey: UserDefaults.Key.isAntiTrackerHardcore)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        antiTrackerSwitch.setOn(UserDefaults.shared.isAntiTracker, animated: false)
        antiTrackerHardcoreSwitch.setOn(UserDefaults.shared.isAntiTrackerHardcore, animated: false)
        antiTrackerHardcoreSwitch.isEnabled = UserDefaults.shared.isAntiTracker
    }

}

// MARK: - UITableViewDelegate -

extension AntiTrackerViewController {
    
    override func tableView(_ tableView: UITableView, willDisplayFooterView view: UIView, forSection section: Int) {
        let footer = view as! UITableViewHeaderFooterView
        footer.textLabel?.textColor = UIColor.init(named: Theme.Key.ivpnLabel6)
        
        let urlString = section > 0 ? "https://www.ivpn.net/antitracker/hardcore" : "https://www.ivpn.net/antitracker"
        
        let label = ActiveLabel(frame: .zero)
        let customType = ActiveType.custom(pattern: "Learn more")
        label.numberOfLines = 0
        label.font = UIFont.systemFont(ofSize: 13)
        label.enabledTypes = [customType]
        label.text = footer.textLabel?.text
        label.textColor = UIColor.init(named: Theme.Key.ivpnLabel6)
        label.customColor[customType] = UIColor.init(named: Theme.Key.ivpnBlue)
        label.handleCustomTap(for: customType) { _ in
            self.openWebPage(urlString)
        }
        footer.addSubview(label)
        footer.textLabel?.text = ""
        label.bindFrameToSuperviewBounds(leading: 16, trailing: -16)
    }
    
    override func tableView(_ tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
        if let header = view as? UITableViewHeaderFooterView {
            header.textLabel?.textColor = UIColor.init(named: Theme.Key.ivpnLabel6)
        }
    }
    
}
