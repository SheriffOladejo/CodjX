//
//  main.swift
//  CodjX Suite Writer
//
//  Created by Ken Chung on 5/12/2020.
//

import CoreSpotlight
import SwiftUI
import UIKit
import ios_system
import LocalAuthentication

struct MainScene: View {
    @EnvironmentObject var themeManager: ThemeManager
    @StateObject var App = MainApp()
    
    let context = LAContext()

    @AppStorage("stateRestorationEnabled") var stateRestorationEnabled = true
    @SceneStorage("root.bookmark") var rootDirectoryBookmark: Data?
    @SceneStorage("openEditors.bookmarks") var openEditorsBookmarksData: Data?
    @SceneStorage("activeEditor.bookmark") var activeEditorBookmark: Data?
    @SceneStorage("activeEditor.monaco.state") var activeEditorMonacoState: String?

    func getOpenEditorsBookmarks() -> [Data] {
        guard let openEditorsBookmarksData else { return [] }
        return (try? PropertyListDecoder().decode([Data].self, from: openEditorsBookmarksData))
            ?? []
    }

    func setOpenEditorsBookmarks(_ v: [Data]) {
        openEditorsBookmarksData = try? PropertyListEncoder().encode(v)
    }

    func saveSceneState() {
        guard stateRestorationEnabled else { return }
        guard let rootDir = App.workSpaceStorage.currentDirectory._url,
            rootDir.isFileURL,
            let rootDirBookmarkData = try? rootDir.bookmarkData()
        else {
            return
        }
        rootDirectoryBookmark = rootDirBookmarkData
        setOpenEditorsBookmarks(App.editorsWithURL.compactMap { try? $0.url.bookmarkData() })

        if let activeEditor = App.activeTextEditor,
            let activeEditorBookmarkData = try? activeEditor.url.bookmarkData()
        {
            activeEditorBookmark = activeEditorBookmarkData
            App.monacoInstance.monacoWebView.evaluateJavaScript(
                "JSON.stringify(editor.saveViewState())"
            ) {
                res, err in
                if let res = res as? String {
                    activeEditorMonacoState = res
                }
            }
        } else {
            activeEditorBookmark = nil
            activeEditorMonacoState = nil
        }
    }
    
    func authenticate(){
            
            var error:NSError?
            
            guard self.context.canEvaluatePolicy(LAPolicy.deviceOwnerAuthenticationWithBiometrics, error: &error) else{
                return print(error!)
            }
            if self.context.biometryType == .faceID {
               //Face id
                print("FaceId")
            }else if self.context.biometryType == .touchID{
                //Touch Id
                print("TouchId")
            }else {
                //none
                authenticate()
                print("None")
            }
            let reason = "Unlock iPhone to continue"
            
            self.context.evaluatePolicy(LAPolicy.deviceOwnerAuthentication, localizedReason: reason) { (isSuccess, error) in
                if isSuccess {
                    //Success
                    print("Success")
                }else{
                    //Error
                    self.showLAError(laError: error!)
                    authenticate()
                }
            }
        }
        
        // function to detect an error type
        func showLAError(laError: Error) -> Void {
            var message = ""
            switch laError {
            case LAError.appCancel:
                message = "Authentication was cancelled by application"
            case LAError.authenticationFailed:
                message = "The user failed to provide valid credentials"
            case LAError.invalidContext:
                message = "The context is invalid"
            case LAError.passcodeNotSet:
                message = "Passcode is not set on the device"
            case LAError.systemCancel:
                message = "Authentication was cancelled by the system"
            case LAError.biometryLockout:
                message = "Too many failed attempts."
                case LAError.biometryNotAvailable:
                message = "TouchID is not available on the device"
            case LAError.userCancel:
                message = "The user did cancel"
            case LAError.userFallback:
                message = "The user chose to use the fallback"
            default:
                if #available(iOS 11.0, *) {
                    switch laError {
                    case LAError.biometryNotAvailable:
                        message = "Biometry is not available"
                    case LAError.biometryNotEnrolled:
                        message = "Authentication could not start, because biometry has no enrolled identities"
                    case LAError.biometryLockout:
                        message = "Biometry is locked. Use passcode."
                    default:
                        message = "Did not find error code on LAError object"
                    }
                }else{
                    message = "Did not find error code on LAError object"
                }
            }
            //return message
            print("LAError message - \(message)")
        }
    
    
    func restoreSceneState() {

        var isStale = false

        guard stateRestorationEnabled else { return }
        guard let rootDirBookmark = rootDirectoryBookmark,
            let rootDir = try? URL(
                resolvingBookmarkData: rootDirBookmark, bookmarkDataIsStale: &isStale)
        else {
            return
        }
        App.loadFolder(url: rootDir)

        let editors = getOpenEditorsBookmarks().compactMap {
            try? URL(resolvingBookmarkData: $0, bookmarkDataIsStale: &isStale)
        }
        for editor in editors {
            App.openFile(url: editor, alwaysInNewTab: true)
        }

        if let activeEditorBookmark = activeEditorBookmark,
            let activeEditor = try? URL(
                resolvingBookmarkData: activeEditorBookmark, bookmarkDataIsStale: &isStale)
        {
            App.openFile(url: activeEditor)
        }

    }

    var body: some View {
        MainView()
            .environmentObject(App)
            .environmentObject(App.extensionManager)
            .environmentObject(App.stateManager)
            .environmentObject(App.alertManager)
            .environmentObject(App.safariManager)
            .onAppear {
                restoreSceneState()
                App.extensionManager.initializeExtensions(app: App)
                authenticate()
            }
            .onOpenURL { url in
                _ = url.startAccessingSecurityScopedResource()
                App.openFile(url: url.standardizedFileURL)
            }
            .onReceive(
                NotificationCenter.default.publisher(
                    for: UIApplication.willResignActiveNotification)
            ) { _ in
                saveSceneState()
            }
            .onReceive(
                NotificationCenter.default.publisher(
                    for: Notification.Name("theme.updated"),
                    object: nil
                ),
                perform: { notification in
                    guard var theme = themeManager.currentTheme else {
                        if let isDark = notification.userInfo?["isDark"] as? Bool {
                            App.monacoInstance.executeJavascript(command: "resetTheme(\(isDark))")
                            App.terminalInstance.executeScript("applyTheme(null, \(isDark))")
                        }
                        return
                    }
                    App.monacoInstance.setTheme(
                        themeName: theme.name.replacingOccurrences(of: " ", with: ""),
                        data: theme.jsonString,
                        isDark: theme.isDark)
                    App.terminalInstance.applyTheme(rawTheme: theme.dictionary)
                }
            )
            .hiddenSystemOverlays()
    }
}

enum SideBarSection: Int {
    case explorer
    case search
    case sourceControl
    case remote
}

private struct MainView: View {

    @EnvironmentObject var App: MainApp
    @EnvironmentObject var extensionManager: ExtensionManager
    @EnvironmentObject var stateManager: MainStateManager
    @EnvironmentObject var alertManager: AlertManager
    @EnvironmentObject var safariManager: SafariManager
    @EnvironmentObject var themeManager: ThemeManager

    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    @Environment(\.colorScheme) var colorScheme: ColorScheme

    @AppStorage("editorFontSize") var editorTextSize: Int = 14
    @AppStorage("editorReadOnly") var editorReadOnly = false
    @AppStorage("compilerShowPath") var compilerShowPath = false
    @AppStorage("changelog.lastread") var changeLogLastReadVersion = "0.0"

    @SceneStorage("sidebar.visible") var isSideBarVisible: Bool = DefaultUIState.SIDEBAR_VISIBLE
    @SceneStorage("sidebar.tab") var currentSideBarTab: SideBarSection = DefaultUIState.SIDEBAR_TAB
    @SceneStorage("panel.height") var panelHeight: Double = DefaultUIState.PANEL_HEIGHT
    @SceneStorage("panel.visible") var isPanelVisible: Bool = DefaultUIState.PANEL_IS_VISIBLE

    func openConsolePanel() {
        if panelHeight < 70 {
            panelHeight = 200
        }
        isPanelVisible.toggle()
        App.terminalInstance.webView?.becomeFirstResponder()
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: 0) {
                        if horizontalSizeClass == .regular {
                            ActivityBar(openConsolePanel: openConsolePanel)

                            if isSideBarVisible {
                                ZStack(alignment: .topLeading) {
                                    Group {
                                        switch currentSideBarTab {
                                        case .explorer:
                                            ExplorerContainer()
                                        case .search:
                                            SearchContainer()
                                        case .sourceControl:
                                            SourceControlContainer()
                                        case .remote:
                                            RemoteContainer()
                                        }
                                    }
                                    .background(Color.init(id: "sideBar.background"))
                                }
                                .frame(width: 280.0, height: geometry.size.height - 20)
                                .background(Color.init(id: "sideBar.background"))
                            }
                        }

                        ZStack {
                            VStack(spacing: 0) {
                                TopBar(openConsolePanel: openConsolePanel)
                                    .environmentObject(extensionManager.toolbarManager)
                                    .frame(height: 40)

                                EditorView()
                                    .disabled(horizontalSizeClass == .compact && isSideBarVisible)
                                    .sheet(isPresented: $stateManager.showsNewFileSheet) {
                                        NewFileView(
                                            targetUrl: App.workSpaceStorage.currentDirectory.url
                                        ).environmentObject(App)
                                    }
                                    .environmentObject(extensionManager.editorProviderManager)

                                if isPanelVisible {
                                    PanelView()
                                        .environmentObject(extensionManager.panelManager)
                                }
                            }
                            .blur(
                                radius: (horizontalSizeClass == .compact && isSideBarVisible)
                                    ? 10 : 0)

                            if isSideBarVisible && horizontalSizeClass == .compact {
                                CompactSidebar()
                            }
                        }
                    }
                    BottomBar(
                        openConsolePanel: openConsolePanel,
                        onDirectoryPickerFinished: {
                            currentSideBarTab = .explorer
                            isSideBarVisible = true
                        }
                    )
                    .frame(width: geometry.size.width, height: 20)
                }

                HStack {
                    Spacer()
                    VStack {
                        Spacer()
                        NotificationCentreView().padding(
                            .trailing, (self.horizontalSizeClass == .compact ? 40 : 10))
                    }
                }.padding(.bottom, 30).frame(width: geometry.size.width)

            }
        }
        .background(Color.init(id: "sideBar.background").edgesIgnoringSafeArea(.all))
        .accentColor(Color.init(id: "activityBar.inactiveForeground"))
        .navigationTitle(
            URL(string: App.workSpaceStorage.currentDirectory.url)?.lastPathComponent ?? ""
        )
        .onChange(of: colorScheme) { newValue in
            App.updateView()
        }
        .hiddenScrollableContentBackground()
        .onAppear {
            let appVersion =
                Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0"

            if changeLogLastReadVersion != appVersion {
                //stateManager.showsChangeLog.toggle()
            }

            changeLogLastReadVersion = appVersion
        }
        .alert(alertManager.title, isPresented: $alertManager.isShowingAlert) {
            alertManager.alertContent
        }
        .fullScreenCover(isPresented: $safariManager.showsSafari) {
            if let url = safariManager.urlToVisit {
                SafariView(url: url)
            } else {
                EmptyView()
            }
        }
    }
}
