import Foundation
import Bolt
@testable import Theo

struct BoltConfig: ClientConfigurationProtocol {
    let hostname: String
    let port: Int
    let username: String
    let password: String
    let encrypted: Bool
    let certificateValidator: CertificateValidatorProtocol

    init(pathToFile: String) {

//        do {
//            let filePathURL = URL(fileURLWithPath: pathToFile)
//            let jsonData = try Data(contentsOf: filePathURL)
//            let JSON = try JSONSerialization.jsonObject(with: jsonData, options: [])
//
//            let jsonConfig = JSON as! [String:Any]
//
//            self.username  = jsonConfig["username"] as! String
//            self.password  = jsonConfig["password"] as! String
//            self.hostname  = jsonConfig["hostname"] as! String
//            self.port      = jsonConfig["port"] as! Int
//            self.encrypted = jsonConfig["encrypted"] as! Bool
//
//        } catch {

            self.username  = "neo4j"
            self.password  = "PlIbpT3lvxvD06NtmH2bDCvN3AA9znJx4qdwShFeFCY"
            self.hostname  = "fa962e09.databases.neo4j.io"
            self.port      = 7687
            self.encrypted = true

//            print("Using default parameters as configuration parsing failed: \(error)")
//        }

        self.certificateValidator = UnsecureCertificateValidator(hostname: self.hostname, port: UInt(self.port))
    }
}
