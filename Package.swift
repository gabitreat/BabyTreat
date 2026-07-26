// swift-tools-version: 5.9
import PackageDescription

#if TUIST
    import ProjectDescription

    let packageSettings = PackageSettings(
        // Customize the product types for given external products
        // productTypes: ["Alamofire": .framework,]
        productTypes: [:]
    )
#endif

let package = Package(
    name: "BabyTreat",
    dependencies: [
        .package(url: "https://github.com/danielgindi/Charts.git", from: "5.0.0")
    ]
)