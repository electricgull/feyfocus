//
//  SQLiteManager.swift
//  FeyFocus
//
//  Created by Cameron Griffin on 4/14/24.
//

import Foundation
import SQLite


class SQLiteManager {
    let db: Connection
    
    struct FilePaths {
        static let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        static let feyFocusDirectory = documentsDirectory.appendingPathComponent("FeyFocus")
        static let dbPath = feyFocusDirectory.appendingPathComponent("FeyFocus.sqlite3").path
    }
    
    
    init() {
        let feyFocusDirectory = FilePaths.feyFocusDirectory
        let dbPath = FilePaths.dbPath
        
        do {
            try FileManager.default.createDirectory(at: feyFocusDirectory, withIntermediateDirectories: true, attributes: nil)
        } catch {
            fatalError("Error creating FeyFocus directory: \(error)")
        }
        
        do {
            db = try Connection(dbPath)
        } catch {
            fatalError("Error connecting to database: \(error)")
        }
        
        do {
            try createDatabaseTables()
        } catch {
            fatalError("Error creating database tables: \(error)")
        }
    }
    
    
    private func createDatabaseTables() throws {
        // open files table
        let openFilesTable = Table("open_files")
        let id = Expression<Int64>("id")
        let projectId = Expression<Int64>("project_id")
        let fileName = Expression<String>("file_name")
        let fileHours = Expression<Double>("file_hours")
        let notes = Expression<String>("notes")

        try db.run(openFilesTable.create(ifNotExists: true) { table in
            table.column(id, primaryKey: .autoincrement)
            table.column(projectId)
            table.column(fileName)
            table.column(fileHours)
            table.column(notes)
            
            table.foreignKey(projectId, references: Table("project"), Expression<Int64>("id"), delete: .cascade)
        })
        
        // customer table
        let projectTable = Table("project")
        let projtId = Expression<Int64>("id")
        let projectName = Expression<String>("project_name")

        try db.run(projectTable.create(ifNotExists: true) { table in
            table.column(projtId, primaryKey: .autoincrement)
            table.column(projectName)
        })
        
        // application table
        
    }

   
    func saveDataToDatabase(openFilesArray: [OpenFiles], completion: @escaping () -> Void) {
    
        do {
            let openFilesTable = Table("open_files")
            let projectId = Expression<Int64>("project_id")
            let fileName = Expression<String>("file_name")
            let openTime = Expression<Double>("file_hours")
            let notes = Expression<String>("notes")

            
            for openFile in openFilesArray {
                let projectName = openFile.project
                let projectTableName = "project"
                let query = "SELECT id FROM \(projectTableName) WHERE project_name = ?"
                
                if let projectIdValue = try db.scalar(query, projectName) as? Int64 {
                    let fileExists = try db.scalar(openFilesTable.filter(fileName == openFile.fileName).count) > 0
                    if fileExists {
                        let update = openFilesTable.filter(fileName == openFile.fileName)
                            .update(openTime <- openFile.openTime,
                                    projectId <- projectIdValue,
                                    notes <- openFile.notes)
                        try db.run(update)
                        
                    } else {
                        let insert = openFilesTable.insert(
                            fileName <- openFile.fileName,
                            openTime <- openFile.openTime,
                            projectId <- projectIdValue,
                            notes <- openFile.notes
                        )
                        try db.run(insert)
                    }
                }
                else {
                    let newProjectId = try createProject(projectName: projectName)
                    let insert = openFilesTable.insert(fileName <- openFile.fileName,
                                                        openTime <- openFile.openTime,
                                                        projectId <- newProjectId,
                                                        notes <- openFile.notes)
                    try db.run(insert)
                }
            }
            print("Data saved to database.")
            completion()
            
        } catch {
            print("Error: \(error)")
        }
    }
    
    func getOpenFiles() -> [OpenFiles] {
        let openFilesTable = Table("open_files")
        let fileName = Expression<String>("file_name")
        let openTime = Expression<Double>("file_hours")
        let projectId = Expression<Int64>("project_id")
        let notes = Expression<String>("notes")
        
        var openFiles: [OpenFiles] = []

        let query = openFilesTable.select(fileName, openTime, projectId, notes)
        
        do {
            let projects = try getProjects()
            
            for fileRow in try db.prepare(query) {
                let fileName = try fileRow.get(fileName)
                let openTime = try fileRow.get(openTime)
                let projectId = try fileRow.get(projectId)
                let notes = try fileRow.get(notes)
                
                let projectName = projects.first(where: { $0.id == projectId })?.name ?? ""
                let openFile = OpenFiles(name: fileName, openTime: openTime, project: projectName, notes: notes)
                
                openFiles.append(openFile)
            }
        } catch {
            print("Error fetching open files: \(error)")
        }
        return openFiles
    }


    
    func getProjects() throws -> [Project] {
            let projectTable = Table("project")
            let projtId = Expression<Int64>("id")
            let projectName = Expression<String>("project_name")
            
            var projects = [Project]()
            
            let query = projectTable.select(projtId, projectName)
            
            for projectRow in try db.prepare(query) {
                let projectId = try projectRow.get(projtId)
                let projectNameValue = try projectRow.get(projectName)
                let project = Project(id: projectId, name: projectNameValue)
                projects.append(project)
            }
            
            return projects
    }
    
    
    
    func createProject(projectName: String) throws -> Int64 {
        let projectTable = Table("project")
        let project_name = Expression<String>("project_name")
        
        let insert = projectTable.insert(project_name <- projectName)
        let newProjectId = try db.run(insert)
        
        return newProjectId
    }
    
    func deleteDatabaseData() throws {
        print("Clearing DB")
        let openFilesTable = Table("open_files")
        let projectTable = Table("project")
        
        try db.run(openFilesTable.delete())
        try db.run(projectTable.delete())
    }
    
}
