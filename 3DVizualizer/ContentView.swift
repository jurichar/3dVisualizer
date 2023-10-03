import SwiftUI
import SceneKit

struct ContentView: View {
    // use the state variables to store the zoom and rotation values
    @State private var zoom: Float = 1
    @State private var rotation: Angle = .zero
    
    var body: some View {
        SceneKitView(zoom: $zoom, rotation: $rotation)
        // add the gestures
            .gesture(MagnifyGesture()
                .onChanged { value in
                    self.zoom = Float(value.magnification)
                    print("Zoom \(self.zoom)")
                }
                .simultaneously(with: DragGesture()
                    .onChanged { value in
                        self.rotation = Angle(degrees: Double(value.translation.width))
                        print("Rotation \(self.rotation.degrees)")
                    }))
    }
}

struct SceneKitView: UIViewRepresentable {
    // get the values from the state variables
    @Binding var zoom: Float
    @Binding var rotation: Angle

    // create the scene view
    func makeUIView(context: Context) -> SCNView {
        let sceneView = SCNView()
        sceneView.scene = SCNScene()
        sceneView.allowsCameraControl = true
        return sceneView
    }
    
    struct Atom {
        let id: Int
        let name: String
        let radius: Float
        let x: Float
        let y: Float
        let z: Float
    }
    
    struct Connect {
        let from: Int
        let to: [Int]
    }
    
func updateUIView(_ uiView: SCNView, context: Context) {
    // init camera
    var cameraNode = uiView.scene?.rootNode.childNode(withName: "cameraNode", recursively: false)

    if (cameraNode == nil) {
        cameraNode = SCNNode()
        cameraNode?.camera = SCNCamera()
        cameraNode?.name = "cameraNode"
        uiView.scene?.rootNode.addChildNode(cameraNode!)
    }
    
    // add camera position
    cameraNode?.position = SCNVector3(x: 0, y: 0, z: 50)
    
    // Light positions
    let lightPositions = [
        SCNVector3(x: 0, y: 0, z: 50),  // Front
        SCNVector3(x: -50, y: 0, z: 0), // Left
        SCNVector3(x: 50, y: 0, z: 0),  // Right
        SCNVector3(x: 0, y: 50, z: 0),  // Top
        SCNVector3(x: 0, y: -50, z: 0), // Bottom
        SCNVector3(x: 0, y: 0, z: -50)  // Back
    ]
    
    for position in lightPositions {
        let lightNode = SCNNode()
        lightNode.light = SCNLight()
        lightNode.light?.type = .omni
        lightNode.light?.intensity = 1000
        lightNode.light?.color = UIColor.white
        lightNode.position = position
        uiView.scene?.rootNode.addChildNode(lightNode)
    }
    
    uiView.setNeedsDisplay()

    let (atoms, connects) = parsePdbFile(name: "DB01718")
    for atom in atoms {
        createAtom(uiView: uiView, atom: atom)
    }
    for connect in connects {
        print (connect.to)
        let from = atoms.first(where: {$0.id == connect.from})
        for to in connect.to {
            let toAtom = atoms.first(where: {$0.id == to})
            createConnection(uiView: uiView, from: from!, to: toAtom!)
        }
    }

}

    func parsePdbFile (name: String) -> ([Atom], [Connect]){

        var atoms: [Atom] = []
        var connects: [Connect] = []
        do {
            guard let filePath = Bundle.main.path(forResource: name, ofType: "pdb") else {
                print("Fichier .pdb introuvable")
                return ([], [])
            }
            let contents = try String(contentsOfFile: filePath)
            let lines = contents.split(separator: "\n")
            for line in lines {
                let words = line.split(separator: " ")
                if (words[0] == "HETATM") {
                    let id = Int(words[1]) ?? 0
                    let name = String(words[2])
                    let radius = 0.5
                    let x = Float(words[5]) ?? 0.0
                    let y = Float(words[6]) ?? 0.0
                    let z = Float(words[7]) ?? 0.0
                    atoms.append(Atom(id: id, name: name, radius: Float(radius), x: x, y:y, z:z))
                }
                if (words[0] == "CONECT") {
                    let from = Int(words[1]) ?? 0
                    let to = words[2...].compactMap { Int($0) }
                    connects.append(Connect(from: from, to: to))
                }
            }
            return (atoms, connects)
        } catch {
            print("Error: \(error)")
            return ([], [])
        }
    }


    func createAtom(uiView: SCNView, atom: Atom){
        var color = UIColor.clear
        switch atom.name {
        case "C":
            color = UIColor.gray
            break;
        case "N":
            color = UIColor.blue
            break;
        default:
            color = UIColor.yellow
        }
        print (atom.name)
        createSphere(uiView: uiView, radius: CGFloat(atom.radius), color: color, x: atom.x, y: atom.y, z: atom.z)
    }
    
    func createSphere(uiView: SCNView, radius: CGFloat, color: UIColor, x: Float, y: Float, z: Float) {
        // add a sphere
        let sphere = SCNSphere(radius: radius)
        let sphereNode = SCNNode(geometry: sphere)
        sphereNode.position = SCNVector3(x: x, y: y, z: z)
        
        // add a material to the sphere
        let material = SCNMaterial()
        material.diffuse.contents = color
        sphere.materials = [material]

        uiView.scene?.rootNode.addChildNode(sphereNode)
    }

    func createConnection (uiView: SCNView, from: Atom, to: Atom) {
        // add coordinates of the first atom
        let fromNode = SCNNode()
        fromNode.position = SCNVector3(x: from.x, y: from.y, z: from.z)
        
        // add coordinates of the second atom
        let toNode = SCNNode()
        toNode.position = SCNVector3(x: to.x, y: to.y, z: to.z)
        
        // add color of the first atom
        var color = UIColor.clear
        switch from.name {
        case "C":
            color = UIColor.gray
            break;
        case "N":
            color = UIColor.blue
            break;
        default:
            color = UIColor.yellow
        }

        // add a line between the two atoms
        makeCylinder(uiView: uiView, positionStart: fromNode.position, positionEnd: toNode.position, radius: 0.2, color: color, transparency: 0.5)

    }

    func makeCylinder(uiView: SCNView, positionStart: SCNVector3, positionEnd: SCNVector3, radius: CGFloat , color: UIColor, transparency: CGFloat){
        let height = CGFloat(GLKVector3Distance(SCNVector3ToGLKVector3(positionStart), SCNVector3ToGLKVector3(positionEnd))) / 2
        let startNode = SCNNode()
        let endNode = SCNNode()

        startNode.position = positionStart
        endNode.position = positionEnd

        let zAxisNode = SCNNode()
        zAxisNode.eulerAngles.x = Float(Double.pi/2)

        let cylinderGeometry = SCNCylinder(radius: radius, height: height)
        cylinderGeometry.firstMaterial?.diffuse.contents = color
        let cylinder = SCNNode(geometry: cylinderGeometry)

        cylinder.position.y = Float(-height/2)
        zAxisNode.addChildNode(cylinder)

        let returnNode = SCNNode()

        if (positionStart.x > 0.0 && positionStart.y < 0.0 && positionStart.z < 0.0 && positionEnd.x > 0.0 && positionEnd.y < 0.0 && positionEnd.z > 0.0)
        {
            endNode.addChildNode(zAxisNode)
            endNode.constraints = [ SCNLookAtConstraint(target: startNode) ]
            returnNode.addChildNode(endNode)

        }
        else if (positionStart.x < 0.0 && positionStart.y < 0.0 && positionStart.z < 0.0 && positionEnd.x < 0.0 && positionEnd.y < 0.0 && positionEnd.z > 0.0)
        {
            endNode.addChildNode(zAxisNode)
            endNode.constraints = [ SCNLookAtConstraint(target: startNode) ]
            returnNode.addChildNode(endNode)

        }
        else if (positionStart.x < 0.0 && positionStart.y > 0.0 && positionStart.z < 0.0 && positionEnd.x < 0.0 && positionEnd.y > 0.0 && positionEnd.z > 0.0)
        {
            endNode.addChildNode(zAxisNode)
            endNode.constraints = [ SCNLookAtConstraint(target: startNode) ]
            returnNode.addChildNode(endNode)

        }
        else if (positionStart.x > 0.0 && positionStart.y > 0.0 && positionStart.z < 0.0 && positionEnd.x > 0.0 && positionEnd.y > 0.0 && positionEnd.z > 0.0)
        {
            endNode.addChildNode(zAxisNode)
            endNode.constraints = [ SCNLookAtConstraint(target: startNode) ]
            returnNode.addChildNode(endNode)

        }
        else
        {
            startNode.addChildNode(zAxisNode)
            startNode.constraints = [ SCNLookAtConstraint(target: endNode) ]
            returnNode.addChildNode(startNode)
        }
        uiView.scene?.rootNode.addChildNode(returnNode)
    }

}


struct TestingModelizationApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
