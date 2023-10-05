//
//  ContentView.swift
//  Derootifier
//
//  Created by Анохин Юрий on 15.04.2023.
//

import SwiftUI
import FluidGradient

struct ContentView: View {
    let scriptPath = Bundle.main.path(forResource: "patch", ofType: "sh")!
    @AppStorage("firstLaunch") private var firstLaunch = true
    @State private var showingSheet = false
    @State private var selectedFile: URL?
    @State private var requiredRootHidePatches: Bool = false
    
    var body: some View {
        
        let _ = NotificationCenter.default.addObserver(forName:Notification.Name("patcherFileOpen"), object: nil, queue: nil) { noti in
            NSLog("RootHidePatcher: patcherFileOpen: \(noti)")
            selectedFile = noti.object as? URL
        }
        
        NavigationView {
            VStack(spacing: 10) {
                
                if let debfile = selectedFile {
                    Text(debfile.lastPathComponent)
                    .padding(10)
                    .opacity(0.5)
                }
                
                Button("Select .deb file") {
                    UISelectionFeedbackGenerator().selectionChanged()
                    showingSheet.toggle()
                }
                .buttonStyle(TintedButton(color: .white, fullwidth: true))
                .padding(20)
                
                if let debfile = selectedFile {
                    Button("Convert .deb") {
                        UINotificationFeedbackGenerator().notificationOccurred(.success)
                        UIApplication.shared.alert(title: "Converting...", body: "Please wait", withButton: false)
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                            
                            let name = debfile.deletingPathExtension().lastPathComponent.replacingOccurrences(of: "arm64", with: "arm64e").replacingOccurrences(of: " ", with: "_")
                            
                            let output = URL.init(fileURLWithPath: "/var/mobile/RootHidePatcher/\(name).deb")
                            
                            let (success,outputAux) = repackDeb(scriptPath: scriptPath, debURL: debfile, outputURL: output)
                            
                            UIApplication.shared.dismissAlert(animated: false)
                            
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                                if success {
                                    selectedFile = nil
                                    UIApplication.shared.confirmAlert(title: "Done", body: outputAux+"\nPress <OK> to view deb file.", onOK: {
                                        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                                        checkFileMngrs(path: output.path)
                                    }, noCancel: false)
                                } else {
                                    UIApplication.shared.alert(title: "Error", body: outputAux)
                                }
                            }
                        }
                    }
                    .buttonStyle(TintedButton(color: .white, fullwidth: true))
                }
                

                if let _ = selectedFile {
                    Toggle("Required RootHide Dynamic Patches", isOn: $requiredRootHidePatches)
                        .toggleStyle(SwitchToggleStyle(tint: Color.blue))
                        .foregroundColor(.white.opacity(0.9))
                        .frame(width: 350)
                        .padding(35)
                        .disabled(true)
                }
                
                NavigationLink(
                    destination: CreditsView(),
                    label: {
                        HStack {
                            Text("Credits")
                            Image(systemName: "chevron.right")
                        }
                        .foregroundColor(.white.opacity(0.8))
                        .font(.system(size: 15))
                    }
                )
                .padding(50)
            }
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background (
                FluidGradient(blobs: [.green, .mint],
                              highlights: [.green, .mint],
                              speed: 0.5,
                              blur: 0.80)
                .background(.green)
            )
            .ignoresSafeArea()
            .onAppear {
//                if firstLaunch {
//                    UIApplication.shared.alert(title: "Warning", body: "Please make sure the following packages are installed: dpkg, file, odcctools, ldid (from Procursus).")
//                    firstLaunch = false
//                }
#if !targetEnvironment(simulator)
                folderCheck()
#endif
            }
            .sheet(isPresented: $showingSheet) {
                DocumentPicker(selectedFile: $selectedFile)
            }
        }
    }
    
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
