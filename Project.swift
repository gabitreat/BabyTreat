import ProjectDescription

let project = Project(
    name: "BabyTreat",
    targets: [
        .target(
            name: "BabyTreat",
            destinations: .iOS,
            product: .app,
            bundleId: "com.yourcompany.babytreat",
            deploymentTargets: .iOS("17.0"),
            infoPlist: .extendingDefault(
                with: [
                    "UILaunchScreen": [
                        "UIColorName": "",
                        "UIImageName": "",
                    ],
                    "UISupportedInterfaceOrientations": [
                        "UIInterfaceOrientationPortrait",
                        "UIInterfaceOrientationLandscapeLeft",
                        "UIInterfaceOrientationLandscapeRight"
                    ],
                    "UISupportedInterfaceOrientations~ipad": [
                        "UIInterfaceOrientationPortrait",
                        "UIInterfaceOrientationPortraitUpsideDown",
                        "UIInterfaceOrientationLandscapeLeft",
                        "UIInterfaceOrientationLandscapeRight"
                    ]
                ]
            ),
            sources: ["BabyTreat/**"],
            resources: ["BabyTreat/*.xcassets", "BabyTreat/**/*.xcdatamodeld"],
            dependencies: []
        )
    ]
)