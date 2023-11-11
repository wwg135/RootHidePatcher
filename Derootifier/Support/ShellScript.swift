//
//  ShellScript.swift
//  Derootifier
//
//  Created by Анохин Юрий on 15.04.2023.
//

//import AuxiliaryExecute
import UIKit

func repackDeb(scriptPath: String, debURL: URL, outputURL: URL, patch: String) -> (Bool,String) {
    var output = ""
    let command = jbroot("/usr/bin/bash")
    let env = ["PATH": "/usr/bin:$PATH"]
    let args = ["-p", rootfs(scriptPath), debURL.path, outputURL.path, patch]

//    assert(setuid(0) == 0)

    NSLog("RootHidePatcher: uid=\(getuid()) euid=\(geteuid()) gid=\(getgid())")
    let receipt = AuxiliaryExecute.spawn(command: command, args: args, environment: env, output: { output += $0 })

    return (receipt.exitCode==0, output)
}

func folderCheck() {
    do {
        if FileManager.default.fileExists(atPath: jbroot("/var/mobile/RootHidePatcher/.Inbox")) {
            print("We're good! :)")
        } else {
            try FileManager.default.createDirectory(atPath: jbroot("/var/mobile/RootHidePatcher/.Inbox"), withIntermediateDirectories: true)
        }
    } catch {
        UIApplication.shared.alert(title: "Error!", body: "There was a problem with making the folder for the deb.", withButton: false)
    }
}

func checkFileMngrs(path: String) {
    NSLog("RootHidePatcher: \(path)")
    let activity = UIActivityViewController(activityItems: [URL(fileURLWithPath: jbroot(path))], applicationActivities: nil)
    
    let window = UIApplication.shared.windows[0] //same as Alert++

    // don't touch this for ipad
    activity.popoverPresentationController?.sourceView = window
    activity.popoverPresentationController?.sourceRect = CGRect(x: window.bounds.midX, y: window.bounds.height, width: 0, height: 0)
    activity.popoverPresentationController?.permittedArrowDirections = UIPopoverArrowDirection.down
    
    UIApplication.shared.present(alert: activity)
    
//    let pathe = jbroot(path).addingPercentEncoding(withAllowedCharacters: .urlPathAllowed)!
//    NSLog("RootHidePatcher: \(pathe)")
//    if UIApplication.shared.canOpenURL(URL(string: "filza://")!) {
//        UIApplication.shared.open(URL(string: "filza://view\(pathe)")!)
//    } else {
//        UIApplication.shared.alert(title: "converted deb file", body: "\(pathe)", withButton: true)
//    }
}
