import Foundation
import Kitura
import LoggerAPI
import Configuration
import CloudEnvironment
import KituraContracts
import Health
import SwiftKuery
import SwiftKueryPostgreSQL

public let projectPath = ConfigurationManager.BasePath.project.path
public let health = Health()

public class App {
    let router = Router()
    let cloudEnv = CloudEnv()
    let meals = Meals()
    let connection = PostgreSQLConnection(host: "localhost", port: 5432, options: [.databaseName("FoodDatabase")])
    
    public init() throws {
    }
    
    func postInit() throws {
        // Capabilities
        initializeMetrics(app: self)
        
        // Endpoints
        initializeHealthRoutes(app: self)
        
        router.post("/meals", handler: storeHandler)
        router.get("/meals", handler: loadHandler)
    }
    
    func storeHandler(meal: Meal, completion: @escaping (Meal?, RequestError?) -> Void ) -> Void {
        connection.connect() { error in
            if error != nil {return}
            else {
                // Build and execute your query here.
                let insertQuery = Insert(into: meals, values: [meal.name, String(describing: meal.photo), meal.rating])
                connection.execute(query: insertQuery) { result in
                    // Respond to the result here
                    completion(meal, nil)
                }
            }
        }
    }
    
    func loadHandler(completion: @escaping ([Meal]?, RequestError?) -> Void ) -> Void {
        connection.connect() { error in
            if error != nil {return}
            else {
                // Build and execute your query here.
                let selectQuery = Select(from :meals)
                connection.execute(query: selectQuery) { queryResult in
                    // Handle your result here
                    var tempMealStore = [Meal]()
                    if let resultSet = queryResult.asResultSet {
                        for row in resultSet.rows {
                            // Process rows
                            guard let name = row[0], let nameString = name as? String else{return}
                            guard let photo = row[1], let photoString = photo as? String else{return}
                            guard let photoData = photoString.data(using: .utf8) else {return}
                            guard let rating = row[2], let ratingInt = Int(String(describing: rating)) else{return}
                            guard let currentMeal = Meal(name: nameString, photo: photoData, rating: ratingInt) else{return}
                            tempMealStore.append(currentMeal)
                        }
                    }
                    completion(tempMealStore, nil)
                }
            }
        }
    }
    
    public func run() throws {
        try postInit()
        Kitura.addHTTPServer(onPort: cloudEnv.port, with: router)
        Kitura.run()
    }
}


