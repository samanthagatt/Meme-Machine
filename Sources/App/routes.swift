import Foundation
import Routing
import Vapor
import Leaf
import SwiftGD

/// Register your application's routes here.
///
/// [Learn More →](https://docs.vapor.codes/3.0/getting-started/structure/#routesswift)
public func routes(_ router: Router) throws {
    let rootDir = DirectoryConfig.detect().workDir
    let uploadDir = URL(fileURLWithPath: "\(rootDir)Public/uploads")
    let originalsDir = uploadDir.appendingPathComponent("originals")
    let thumbsDir = uploadDir.appendingPathComponent("thumbs")
    
    router.get { req -> Future<View> in
        let fm = FileManager()
        guard let files = try? fm
            .contentsOfDirectory(at: originalsDir,
                                 includingPropertiesForKeys: nil,
                                 options: [.skipsHiddenFiles])
            else { throw Abort(.internalServerError) }
        let fileNames = files.map { $0.lastPathComponent }
        return try req.view().render("home", ["files": fileNames])
    }
    
    router.post("upload") { req -> Future<Response> in
        struct UserFile: Content {
            var upload: [File]
        }
        return try req.content.decode(UserFile.self)
            .map(to: Response.self) { files in
                let types: [MediaType] = [.png, .jpeg, .gif]
                for file in files.upload {
                    guard let type = file.contentType,
                        types.contains(type) else { continue }
                    let fileName = file.filename
                        .replacingOccurrences(of: " ", with: "-")
                    let origURL = originalsDir.appendingPathComponent(fileName)
                    _ = try? file.data.write(to: origURL)
                    let thumbURL = thumbsDir.appendingPathComponent(fileName)
                    if let image = Image(url: origURL),
                        let resized = image.resizedTo(width: 300) {
                        resized.write(to: thumbURL)
                    }
                }
                return req.redirect(to: "/")
        }
    }
}
