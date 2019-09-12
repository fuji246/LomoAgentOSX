//
//  utils.swift
//  LomoAgent
//
//  Created by Jiantao Fu on 7/20/19.
//  Copyright © 2019 lomoware. All rights reserved.
//

import Cocoa
import Foundation
import os.log

func dialogAlert(message: String, info: String)
{
    let alert = NSAlert()
    alert.messageText = message
    alert.informativeText = info
    alert.alertStyle = NSAlert.Style.warning
    alert.addButton(withTitle: alertOk)
    alert.runModal()
}

func dialogOKCancel(message: String, info: String) -> Bool {
    let alert = NSAlert()
    alert.messageText = message
    alert.informativeText = info
    alert.alertStyle = .warning
    alert.addButton(withTitle: alertOk)
    alert.addButton(withTitle: alertCancel)
    return alert.runModal() == .alertFirstButtonReturn
}

func getBasePath() -> String? {
    let paths = NSSearchPathForDirectoriesInDomains(.applicationSupportDirectory, .userDomainMask, true)
    let basePath = NSURL(fileURLWithPath: paths[0]).appendingPathComponent("lomod")
    var baseDir: String? = basePath!.path
    if !FileManager.default.fileExists(atPath: basePath!.path) {
        do {
            try FileManager.default.createDirectory(atPath: basePath!.path, withIntermediateDirectories: true, attributes: nil)
        } catch let error as NSError {
            os_log("Unable to create directory %{public}s", log: .logic, type: .error, error.debugDescription)
            baseDir = nil
        }
    }

    return baseDir
}

func getLogDir() -> String? {
    let paths = NSSearchPathForDirectoriesInDomains(.libraryDirectory, .userDomainMask, true)
    let logPath = NSURL(fileURLWithPath: paths[0]).appendingPathComponent("Logs")?.appendingPathComponent("lomod")
    var logDir: String? = logPath!.path
    if !FileManager.default.fileExists(atPath: logPath!.path) {
        do {
            try FileManager.default.createDirectory(atPath: logPath!.path, withIntermediateDirectories: true, attributes: nil)
        } catch let error as NSError {
            os_log("Unable to create directory %{public}s", log: .logic, type: .error, error.debugDescription)
            logDir = nil
        }
    }

    return logDir
}

protocol NetworkSession {
    func loadData(with url: URL, completionHandler: @escaping (Data?, URLResponse?, Error?) -> Swift.Void, sync group: DispatchGroup?)

    func uploadFile(with request: URLRequest, fromFile fileURL: URL, completionHandler: @escaping (Data?, URLResponse?, Error?) -> Swift.Void)

    func uploadFile(with request: URLRequest, fromFile fileURL: URL) -> URLSessionTask

    func downloadFile(with request: URLRequest) -> URLSessionTask

    func reqData(with req: URLRequest, completionHandler: @escaping (Data?, URLResponse?, Error?) -> Swift.Void, sync group: DispatchGroup?)

    func cancelTasksById(id: Int)

    func stop()
}

extension URLSession: NetworkSession {
    func loadData(with url: URL, completionHandler: @escaping (Data?, URLResponse?, Error?) -> Swift.Void, sync group: DispatchGroup?) {
        let task = dataTask(with: url) { data, response, error in
            completionHandler(data, response, error)
            group?.leave()
        }
        task.resume()
    }

    func reqData(with req: URLRequest, completionHandler: @escaping (Data?, URLResponse?, Error?) -> Swift.Void, sync group: DispatchGroup?) {
        let task = dataTask(with: req) { data, response, error in
            completionHandler(data, response, error)
            group?.leave()
        }
        task.resume()
    }

    func uploadFile(with request: URLRequest, fromFile fileURL: URL, completionHandler: @escaping (Data?, URLResponse?, Error?) -> Swift.Void) {
        let task = uploadTask(with: request, fromFile: fileURL, completionHandler: completionHandler)
        task.resume()
    }

    func uploadFile(with request: URLRequest, fromFile fileURL: URL) -> URLSessionTask {
        let task = uploadTask(with: request, fromFile: fileURL)
        return task
    }

    func downloadFile(with request: URLRequest) -> URLSessionTask {
        let task = downloadTask(with: request)
        return task
    }

    private func cancelTasksByUrl(tasks: [URLSessionTask], url: String)
    {
        for task in tasks {
            if (task.currentRequest?.url?.description.starts(with: url))! {
                task.cancel()
            }
        }
    }

    func cancelTasksById(id: Int)
    {
        getTasksWithCompletionHandler {
            (dataTasks, uploadTasks, downloadTasks) -> Void in

            for task in dataTasks {
                if (task.taskIdentifier == id) {
                    //DDLogInfo("cancelTasksById in dataTasks: \(id)")
                    task.cancel()
                    return
                }
            }
            for task in uploadTasks {
                if (task.taskIdentifier == id) {
                    //DDLogInfo("cancelTasksById in uploadTasks: \(id)")
                    task.cancel()
                    return
                }
            }
            for task in downloadTasks {
                if (task.taskIdentifier == id) {
                    //DDLogInfo("cancelTasksById in downloadTasks: \(id)")
                    task.cancel()
                    return
                }
            }
        }
    }

    private func cancelTasks(tasks: [URLSessionTask])
    {
        for task in tasks {
            //DDLogInfo("cancelTasks: \(task.taskIdentifier)")
            task.cancel()
        }
    }

    func stop() {
        getTasksWithCompletionHandler {
            (dataTasks, uploadTasks, downloadTasks) -> Void in
            self.cancelTasks(tasks: dataTasks)
            self.cancelTasks(tasks: uploadTasks)
            self.cancelTasks(tasks: downloadTasks)
        }
    }
}

func runCommand(cmd : String, args : String...) -> (output: [String], error: [String], exitCode: Int32) {

    var output : [String] = []
    var error : [String] = []

    let task = Process()
    task.launchPath = cmd
    task.arguments = args

    let outpipe = Pipe()
    task.standardOutput = outpipe
    let errpipe = Pipe()
    task.standardError = errpipe

    task.launch()

    let outdata = outpipe.fileHandleForReading.readDataToEndOfFile()
    if var string = String(data: outdata, encoding: .utf8) {
        string = string.trimmingCharacters(in: .newlines)
        output = string.components(separatedBy: "\n")
    }

    let errdata = errpipe.fileHandleForReading.readDataToEndOfFile()
    if var string = String(data: errdata, encoding: .utf8) {
        string = string.trimmingCharacters(in: .newlines)
        error = string.components(separatedBy: "\n")
    }

    task.waitUntilExit()
    let status = task.terminationStatus

    return (output, error, status)
}