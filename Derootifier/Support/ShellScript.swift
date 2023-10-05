//
//  ShellScript.swift
//  Derootifier
//
//  Created by Анохин Юрий on 15.04.2023.
//

import AuxiliaryExecute
import UIKit

func repackDeb(scriptPath: String, debURL: URL, outputURL: URL) -> (Bool,String) {
    var output = ""
    let command = jbroot("/usr/bin/bash")
    let env = ["PATH": "/usr/bin:$PATH"]
    let args = ["-p", rootfs(scriptPath), debURL.path, outputURL.path]

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
    let pathe = jbroot(path) //.replacingOccurrences(of: " ", with: "%20")
    NSLog("RootHidePatcher: \(pathe)")
    if UIApplication.shared.canOpenURL(URL(string: "filza://")!) {
        UIApplication.shared.open(URL(string: "filza://\(pathe)")!)
    } else {
        if UIApplication.shared.canOpenURL(URL(string: "santander://")!) {
            UIApplication.shared.open(URL(string: "santander://\(pathe)")!)
        } else {
            UIApplication.shared.alert(title: "Aw... :(", body: "jbroot:\(path)", withButton: true)
        }
    }
}
