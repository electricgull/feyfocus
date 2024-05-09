//
//  OpenFiles.swift
//  FeyFocus
//
//  Created by Cameron Griffin on 4/14/24.
//

import Foundation

class Project: Identifiable, Hashable {
    let id: Int64
    let name: String
    
    init(id: Int64, name: String) {
        self.id = id
        self.name = name
    }
    
    static func == (lhs: Project, rhs: Project) -> Bool {
        return lhs.id == rhs.id && lhs.name == rhs.name
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(name)
    }
}

class OpenFiles: ObservableObject {
    let id: Int64
    var fileName: String
    var origTime: Date?
    var openTime: Double
    var openTimeText: String {
        get {
            return String(format: "%.0f", openTime)
        }
        set {
            if let newValue = Double(newValue) {
                openTime = newValue
            }
        }
    }
    var project: String
    var notes: String
    
    init(name: String, origTime: Date? = nil, openTime: Double, project: String, notes: String) {
        self.id = Int64()
        self.fileName = name
        self.origTime = origTime
        self.openTime = openTime
        self.project = project
        self.notes = notes
    }
}

