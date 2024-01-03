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
    @State private var simpleTweak: Bool = false
    @State private var usingRootlessCompat: Bool = true
    @State private var requireDynamicPatches: Bool = false
    
    func resetPatches() {
        simpleTweak = false
        usingRootlessCompat = true
        requireDynamicPatches = false
    }
    
    var body: some View {
        
        let _ = NotificationCenter.default.addObserver(forName:Notification.Name("patcherFileOpen"), object: nil, queue: nil) { noti in
            NSLog("RootHidePatcher: patcherFileOpen: \(noti)")
            UIApplication.shared.keyWindow?.rootViewController?.presentedViewController?.dismiss(animated: true)
            selectedFile = noti.object as? URL
            resetPatches()
        }
        
        //NavigationView {
            VStack(spacing: 10) {
                
                if let debfile = selectedFile {
                    Text(debfile.lastPathComponent)
                        .padding(30)
                        .opacity(0.5)
                }
                
                Button("选择转换的.deb插件") {
                    UISelectionFeedbackGenerator().selectionChanged()
                    showingSheet.toggle()
                }
                .buttonStyle(TintedButton(color: .white, fullwidth: true))
                .padding(5)
                
                if let debfile = selectedFile {
                    Button("确定转换") {
                        UINotificationFeedbackGenerator().notificationOccurred(.success)
                        UIApplication.shared.alert(title: "正在转换...", body: "请等待...", withButton: false)
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                            
                            let name = debfile.deletingPathExtension().lastPathComponent.replacingOccurrences(of: "iphoneos-arm64", with: "-a-r-c-h-").replacingOccurrences(of: "iphoneos-arm", with: "-a-r-c-h-").replacingOccurrences(of: "-a-r-c-h-", with: "iphoneos-arm64e")
                            
                            let output = URL.init(fileURLWithPath: "/var/mobile/RootHidePatcher/\(name).deb")
                            
                            var patch=""
                            if usingRootlessCompat { patch="AutoPatches" } else if requireDynamicPatches { patch="DynamicPatches" }
                            let (success,outputAux) = repackDeb(scriptPath: scriptPath, debURL: debfile, outputURL: output, patch: patch)
                            
                            UIApplication.shared.dismissAlert(animated: false)
                            
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                                if success {
                                    resetPatches()
                                    selectedFile = nil
                                    UIApplication.shared.confirmAlert(title: "完成", body: outputAux+"\n请按下<好的>按钮查看deb文件.", onOK: {
                                        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                                        checkFileMngrs(path: output.path)
                                    }, noCancel: true)
                                } else {
                                    UIApplication.shared.alert(title: "错误", body: outputAux)
                                }
                            }
                        }
                    }
                    .buttonStyle(TintedButton(color: .white, fullwidth: true))
                    .padding(30)
                }
                
                
                if let _ = selectedFile {
                    Toggle("直接转换简单插件", isOn: $simpleTweak)
                        .toggleStyle(SwitchToggleStyle(tint: Color.blue))
                        .foregroundColor(.white.opacity(0.9))
                        .frame(width: 350)
                        .padding(5)
                        .disabled(false).onChange(of: simpleTweak) { value in
                            if value {
                                usingRootlessCompat = false
                                requireDynamicPatches = false
                            }
                        }
                    Toggle("仅使用无根兼容层", isOn: $usingRootlessCompat)
                        .toggleStyle(SwitchToggleStyle(tint: Color.blue))
                        .foregroundColor(.white.opacity(0.9))
                        .frame(width: 350)
                        .padding(5)
                        .disabled(false).onChange(of: usingRootlessCompat) { value in
                            if value {
                                simpleTweak = false
                                requireDynamicPatches = false
                            }
                        }
                    Toggle("需要动态修补程序", isOn: $requireDynamicPatches)
                        .toggleStyle(SwitchToggleStyle(tint: Color.blue))
                        .foregroundColor(.white.opacity(0.9))
                        .frame(width: 350)
                        .padding(5)
                        .disabled(false).onChange(of: requireDynamicPatches) { value in
                            if value {
                                simpleTweak = false
                                usingRootlessCompat = false
                            }
                        }
                }
                
                NavigationLink(
                    destination: CreditsView(),
                    label: {
                        HStack {
                            Text("感谢")
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
            .sheet(isPresented: $showingSheet) {
                DocumentPicker(selectedFile: $selectedFile)
            }
        }
    //}
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
