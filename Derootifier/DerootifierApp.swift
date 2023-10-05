//
//  DerootifierApp.swift
//  Derootifier
//
//  Created by Анохин Юрий on 15.04.2023.
//

import SwiftUI

@main
struct DerootifierApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
            .onOpenURL { (url) in
                 NSLog("RootHidePatcher: onOpenURL=\(url)")

                let fileManager = FileManager.default
                
                guard fileManager.fileExists(atPath: url.path) else { return }
                
                let destFolderURL = URL(fileURLWithPath: jbroot("/var/mobile/RootHidePatcher/.Inbox"))
                
                do {
                    try fileManager.createDirectory(at: destFolderURL, withIntermediateDirectories: true, attributes: nil)
                } catch {
                    print(error.localizedDescription)
                    return
                }
                
                let destFileURL = destFolderURL.appendingPathComponent(url.lastPathComponent)
                
                do {
                    if fileManager.fileExists(atPath: destFileURL.path) {
                        try fileManager.removeItem(at: destFileURL)
                    }
                    
                    try fileManager.copyItem(at: url, to: destFileURL)

                    NotificationCenter.default.post(name: Notification.Name("patcherFileOpen"), object: destFileURL)
                    
                } catch {
                    print(error.localizedDescription)
                }
                
            }
        }
    }
}
