//
//  ContentView.swift
//  AppTracker
//
//  Created by Cameron Griffin on 1/26/24.
//

import SwiftUI
import Foundation
import UniformTypeIdentifiers
    
var selectedAppURL: URL?

/*----------------------------
 Data structs and classes
------------------------------*/
struct Option: Hashable{
    let title: String
    let imageName: String
}


/*----------------------------
 Views
------------------------------*/
struct ContentView: View {
    @State private var openFilesArray: [OpenFiles] = []
    @State private var appStarted = false
    var sqliteManager = SQLiteManager()
    
    var body: some View {
        VStack {
            MainView(sqliteManager: sqliteManager, openFilesArray: $openFilesArray)
            TableView(sqliteManager: sqliteManager, openFilesArray: $openFilesArray)
        }
        .onAppear {
            if !appStarted {
                do {
                    openFilesArray = try sqliteManager.getOpenFiles()
                    appStarted = true
                } catch {
                    print("Error fetching open files: \(error)")
                }
            }
        }
    }
}



struct TableView: View {
    let sqliteManager: SQLiteManager
    @Binding var openFilesArray: [OpenFiles]
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    @State private var openFileList: [String] = []
    @State private var selectedProject: Project?
    

    
    var body: some View {
        List {
            HStack {
                Text("Document").frame(width: 200, alignment: .leading)
                Spacer()
                Text("Total Time").frame(width: 100, alignment: .leading)
                Spacer()
                Text("Project").frame(width: 200, alignment: .leading)
                Spacer()
                Text("Notes").frame(maxWidth: .infinity, alignment: .leading)
            }
            .font(.headline)
            updateOpenFilesView()
        }
    }
    func updateOpenFilesView() -> some View {
        
        Form {
            ForEach(openFilesArray.indices, id: \.self) { index in
                let file = $openFilesArray[index]
                HStack {
                    Text(file.fileName.wrappedValue).frame(width: 200, alignment: .leading)
                    TextField("", text: file.openTimeText).frame(width: 100, alignment: .leading)
                    // TODO change project to a picker. Found bug that caused issues when saving data
                    TextField("", text: file.project).frame(width: 200, alignment: .leading)
                    TextField("", text: file.notes).frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .onReceive(timer) { _ in
            updateOpenFiles() { paths in
                for file in paths{
                    let fileName = (file as NSString).lastPathComponent
                    openFilesArray = addOrUpdateFile(fileName: fileName, fileList: openFilesArray, sqliteManager: sqliteManager)
                }
            }
        }
    }
    
}

struct MainView: View {
    let sqliteManager: SQLiteManager
    @State private var selectButtonText = "Select Application"
    @State private var saveButtonText = "Save"
    @State private var exportButtonText = "Export"
    @State private var clearButtonText = "Clear All Data"
    @State private var newProjectName = ""
    @State private var showSavedAlert = false
    @State private var showProjetAlert = false
    @Binding var openFilesArray: [OpenFiles]
    @State private var projects: [Project] = []
    @State private var isShowingProjects = false
    
    private var fileURL: URL!
    
    var body: some View {
        HStack {
            Button(selectButtonText) {
                selectApplication()
            }
            Button("Show Projects") {
                do {
                    projects = try sqliteManager.getProjects() ?? []
                    isShowingProjects.toggle()
                } catch {
                    print("Error fetching projects: \(error)")
                }
            }
            Spacer()
            Button(saveButtonText){
                saveData()
            }
            .alert(isPresented: $showSavedAlert) {
                Alert(title: Text("Success"), message: Text("Data saved successfully"), dismissButton: .default(Text("OK")))
            }
            Button(exportButtonText){
                exportData()
            }
            Button(clearButtonText){
                clearData()
            }
        }
        if isShowingProjects {
            List(projects, id: \.id) { project in
                Text(project.name)
            }
            .padding()
        }
    }
    
    init(sqliteManager: SQLiteManager, openFilesArray: Binding<[OpenFiles]>) {
        self.sqliteManager = sqliteManager
        self._openFilesArray = openFilesArray
    }
    
    func addProject(projectName: String) {
        do {
            // Get the list of existing projects
            let existingProjects = try sqliteManager.getProjects()
            
            // Check if the project already exists
            if existingProjects.contains(where: { $0.name == projectName }) {
                // Project already exists, do nothing
                print("Project already exists")
            } else {
                // Project doesn't exist, create it
                let newProjectId = try sqliteManager.createProject(projectName: projectName)
                print("New project created with ID: \(newProjectId)")
            }
        } catch {
            print("Error adding project: \(error)")
        }
    }
    
    private func selectApplication() {
        let openPanel = NSOpenPanel()
        openPanel.title = "Select Application"
        openPanel.prompt = "Select"
        openPanel.canChooseFiles = true
        openPanel.canChooseDirectories = false
        openPanel.allowedContentTypes = [UTType.application]
        openPanel.directoryURL = URL(fileURLWithPath: "/Applications")
        
        guard openPanel.runModal() == .OK,
              let url = openPanel.urls.first,
              url.pathExtension == "app" else {
            return
        }
        
        selectedAppURL = url
        selectButtonText = "\(url.lastPathComponent)\n\n"
    }
    
    // To Do Pass in array
    private func exportData(){
        var csvString = "Document,Total Time,Project,Notes\n"
        
        for fileData in openFilesArray {
            csvString.append("\(fileData.fileName),\(Int(fileData.openTime)),\(fileData.project),\(fileData.notes)\n")
        }
        
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [UTType.commaSeparatedText]
        savePanel.directoryURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        savePanel.canCreateDirectories = true
        savePanel.isExtensionHidden = false
        savePanel.title = "Save your csv"
        savePanel.message = "Choose a folder and a name to save the csv."
        savePanel.nameFieldLabel = "CSV file name:"
        let response = savePanel.runModal()
        if response == .OK {
            guard let url = savePanel.url else {
                print("Error: Unable to retrieve URL from save panel.")
                return
            }
            do {
                try csvString.write(to: url, atomically: true, encoding: .utf8)
                print("File saved successfully at: \(url)")
                return
            } catch {
                print("Error saving file: \(error)")
            }
        } else {
            print("Save operation canceled by user.")
        }
    }
    
    private func saveData(){
        sqliteManager.saveDataToDatabase(openFilesArray: openFilesArray) {
        }
        showSavedAlert = true
    }
    
    private func clearData() {
        openFilesArray.removeAll()
        do {
            try sqliteManager.deleteDatabaseData()
        } catch {
            print("Error clearing data: \(error)")
        }
    }
}


// Not using previews
/*
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
*/


/*----------------------------
 functions
------------------------------*/

func dialogAlert(text: String) -> Void{
    let alert: NSAlert = NSAlert()
    alert.messageText = ("Error: ")
    alert.informativeText = text
    alert.alertStyle = .critical
    alert.addButton(withTitle: "Ok")
}

func addOrUpdateFile(fileName: String, fileList: [OpenFiles], sqliteManager: SQLiteManager) -> [OpenFiles] {
    var updatedFileList = fileList
    let currentTime = Date()
    
    if let existingFileIndex = fileList.firstIndex(where: { $0.fileName == fileName }) {
        if let origTime = fileList[existingFileIndex].origTime {
            
            let openTime = fileList[existingFileIndex].openTime
            let openTimeSecs = (fileList[existingFileIndex].openTime ) / 60
            let timeDifference = (currentTime.timeIntervalSince(origTime) + openTimeSecs)
            let timeDifferenceInMins = floor(timeDifference / 60)
            
            if ( ( timeDifferenceInMins + openTime ) > openTime) {
                updatedFileList[existingFileIndex].openTime = timeDifferenceInMins + openTime
                updatedFileList[existingFileIndex].origTime = currentTime
                sqliteManager.saveDataToDatabase(openFilesArray: updatedFileList) {
                }
                
            }
            
        } else {
            updatedFileList[existingFileIndex].origTime = currentTime
        }
    } else {
        let defaultOpenTimeInMinutes = 1.0
        let newFile = OpenFiles(name: fileName,
                                origTime: currentTime,
                                openTime: defaultOpenTimeInMinutes,
                                project: "",
                                notes: "")
        updatedFileList.append(newFile)
    }
    return updatedFileList
}

func frontmostApplication() -> (appURL: String, appPID: Int32 ) {
    let frontApp = NSWorkspace.shared.frontmostApplication!
    let currentAppUrl = frontApp.bundleURL?.path() ?? "Unknown"
    let currentPID = frontApp.processIdentifier
    
    if ( currentAppUrl != "Unknown"){
        return (appURL: currentAppUrl, appPID: currentPID)
    }
    return ("*Error*", 0)
}

func updateOpenFiles(completion: @escaping ([String]) -> Void) {
    @State var frontApp = frontmostApplication()
    var openFilesList: [String] = []
    var errorDisplayed = false
    
    guard let selectedAppURL = selectedAppURL else {
        completion([])
        return
    }
    
    let selectedAppPID = NSWorkspace.shared
        .runningApplications
        .first(where: { $0.bundleURL == selectedAppURL })?.processIdentifier ?? 0
    
    if selectedAppPID == 0 || frontApp.appPID != selectedAppPID {
        completion([])
        return
    }
    
    getOpenFiles(forPID: selectedAppPID) { files, error in
        DispatchQueue.main.async {
            if let error = error, !errorDisplayed {
                errorDisplayed = true
                let errorMessage = "\(error)"
                let alert = NSAlert()
                alert.messageText = "Error"
                alert.informativeText = errorMessage
                alert.addButton(withTitle: "OK")
                alert.runModal()
            } else if let files = files {
                for file in files {
                    let fileName = (file.lastPathComponent as NSString).deletingPathExtension
                    openFilesList.append(fileName)
                }
                completion(openFilesList)
            }
        }
    }
}

func getOpenFiles(forPID pid: pid_t, completion: @escaping ([URL]?, Error?) -> Void) {
    DispatchQueue.global(qos: .background).async {
        var currentOpenFiles: [URL] = []

        let script = """
        tell application "System Events"
            set fileList to {}
            repeat with p in processes
                try
                    if unix id of p is \(pid) then
                        try
                            repeat with w in windows of p
                                try
                                    set filePath to value of attribute "AXDocument" of w
                                    if filePath is not missing value then
                                        set end of fileList to filePath
                                    end if
                                end try
                            end repeat
                        end try
                    end if
                end try
            end repeat
        end tell
        
        return fileList
        """
        
        let scriptObject = NSAppleScript(source: script)
        
        var error: NSDictionary?
        let outputDescriptor = scriptObject?.executeAndReturnError(&error)
        if let error = error {
            print("Error:", error)
            DispatchQueue.main.async {
                completion(nil, NSError(domain: "ScriptErrorDomain", code: -1, userInfo: ["errorDescription": "\(error)"]))
            }
        } else {
            if let outputDescriptor = outputDescriptor {
                for i in 0...outputDescriptor.numberOfItems {
                    if let filePathString = outputDescriptor.atIndex(i)?.stringValue,
                       let fileURL = URL(string: filePathString) {
                        currentOpenFiles.append(fileURL)
                    }
                }
            }

            completion(currentOpenFiles, nil)
        }
    }
}
