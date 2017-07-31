//
//  MainViewController.swift
//  OpenLive
//
//  Created by GongYuhua on 6/25/16.
//  Copyright © 2016 Agora. All rights reserved.
//

import UIKit

class MainViewController: UIViewController {

    @IBOutlet weak var roomNameTextField: UITextField!
    @IBOutlet weak var popoverSourceView: UIView!
    
    @IBOutlet weak var ownerView: UIView!
    @IBOutlet weak var ownerImg: UIImageView!
    @IBOutlet weak var ownerLab: UILabel!
    
    @IBOutlet weak var unOwnerView: UIView!
    @IBOutlet weak var unOwnerImg: UIImageView!
    @IBOutlet weak var unOwnerLab: UILabel!
    
    
    var isSelected: Bool = true
    
    override func viewDidLoad() {
        super.viewDidLoad()
        ownerLab.textColor = UIColor.init(red: 55/255, green: 135/255, blue: 246/255, alpha: 1)
        
        let tap1 = UITapGestureRecognizer.init(target: self, action: #selector(MainViewController.changeSelectedInterface))
        ownerView.addGestureRecognizer(tap1)
        
        let tap2 = UITapGestureRecognizer.init(target: self, action: #selector(MainViewController.changeSelectedInterface))
        unOwnerView.addGestureRecognizer(tap2)
        
    }
    
    fileprivate var videoProfile = AgoraRtcVideoProfile._VideoProfile_360P
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        
        guard let segueId = segue.identifier else {
            return
        }
        
        switch segueId {
        case "mainToSettings":
            let settingsVC = segue.destination as! SettingsViewController
            settingsVC.videoProfile = videoProfile
            settingsVC.delegate = self
        case "mainToLive":
            let liveVC = segue.destination as! LiveRoomViewController
            liveVC.roomName = roomNameTextField.text!
            liveVC.videoProfile = videoProfile
            if let value = sender as? NSNumber, let role = AgoraRtcClientRole(rawValue: value.intValue) {
                liveVC.clientRole = role
            }
            liveVC.delegate = self
            liveVC.isOwner = isSelected
        default:
            break
        }
    }
    
    func changeSelectedInterface(){
        if isSelected {
           isSelected = false
        } else {
           isSelected = true
        }
        
        if isSelected {
            ownerImg.image = UIImage(named: "option_selected")
            unOwnerImg.image = UIImage(named:"option_unSelected")
            ownerLab.textColor = UIColor.init(red: 55/255, green: 135/255, blue: 246/255, alpha: 1)
            unOwnerLab.textColor = UIColor.black
        } else {
            ownerImg.image = UIImage(named: "option_unSelected")
            unOwnerImg.image = UIImage(named:"option_selected")
            
            ownerLab.textColor = UIColor.black
            unOwnerLab.textColor = UIColor.init(red: 55/255, green: 135/255, blue: 246/255, alpha: 1)

        }
    }
    
}

private extension MainViewController {
    func showRoleSelection() {
        let sheet = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        let broadcaster = UIAlertAction(title: "Broadcaster", style: .default) { [weak self] _ in
            self?.join(withRole: .clientRole_Broadcaster)
        }
        let audience = UIAlertAction(title: "Audience", style: .default) { [weak self] _ in
            self?.join(withRole: .clientRole_Audience)
        }
        let cancel = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)
        sheet.addAction(broadcaster)
        sheet.addAction(audience)
        sheet.addAction(cancel)
        sheet.popoverPresentationController?.sourceView = popoverSourceView
        sheet.popoverPresentationController?.permittedArrowDirections = .up
        present(sheet, animated: true, completion: nil)
    }
}

private extension MainViewController {
    func join(withRole role: AgoraRtcClientRole) {
        performSegue(withIdentifier: "mainToLive", sender: NSNumber(value: role.rawValue as Int))
    }
}

extension MainViewController: SettingsVCDelegate {
    func settingsVC(_ settingsVC: SettingsViewController, didSelectProfile profile: AgoraRtcVideoProfile) {
        videoProfile = profile
        dismiss(animated: true, completion: nil)
    }
}

extension MainViewController: LiveRoomVCDelegate {
    func liveVCNeedClose(_ liveVC: LiveRoomViewController) {
        let _ = navigationController?.popViewController(animated: true)
    }
}

extension MainViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        if let string = textField.text , !string.isEmpty {
            if isSelected {
                join(withRole: .clientRole_Broadcaster)
            } else{
                showRoleSelection()
            }
        }
        
        return true
    }
}
