import SwiftUI
import SceneKit

struct ContentView: View {
    @State private var sceneView: SCNView? = nil
    
    var body: some View {
        SceneKitView(sceneView: $sceneView)
    }
}


struct SceneKitView: UIViewRepresentable {
    // get the values from the state variables
    @Binding var sceneView: SCNView?

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var scnView: SCNView?
        var parent: SceneKitView

        init(_ parent: SceneKitView) {
            self.parent = parent
        }
        
        @objc func handleTap(_ gestureRecognize: UITapGestureRecognizer) {
            print("handled")
            guard let scnView = self.scnView else { return }
            
            let p = gestureRecognize.location(in: scnView)
            let hitResults = scnView.hitTest(p, options: [:])
            
            if hitResults.count > 0 {
                let result = hitResults[0]
                if let name = result.node.name {
                    print("Nom de l'atome touché : \(name)")
                    // Récupérer la position de l'atome
                    let atomPosition = result.node.position
                    
                    // Trouver le nœud de la caméra
                    if let cameraNode = scnView.scene?.rootNode.childNode(withName: "cameraNode", recursively: false) {
                        
                        // print("Position de la caméra avant: \(cameraNode.position)")
                        SCNTransaction.begin()
                        SCNTransaction.animationDuration = 0.5 // Durée en secondes
                        cameraNode.position = SCNVector3(x: atomPosition.x, y: atomPosition.y, z: 10)
                        SCNTransaction.commit()
                    }
                }
            } else {
                // Trouver le nœud de la caméra
                if let cameraNode = scnView.scene?.rootNode.childNode(withName: "cameraNode", recursively: false) {
                    
                    // Ajuster la position de la caméra
                    // print("Position de la caméra avant: \(cameraNode.position)")
                    SCNTransaction.begin()
                    SCNTransaction.animationDuration = 0.5 // Durée en secondes
                    cameraNode.position = SCNVector3(x: 0, y: 0, z: 50)
                    SCNTransaction.commit()
                }
            }
        }
        
        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
            return true
        }
    }

    // create the scene view
    func makeUIView(context: Context) -> SCNView {
        let sceneView = SCNView()
        sceneView.scene = SCNScene()
//        sceneView.allowsCameraControl = false
        context.coordinator.scnView = sceneView
        let tapGesture = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap(_:)))
        tapGesture.delegate = context.coordinator
        sceneView.addGestureRecognizer(tapGesture)
        
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
        setupLights(in: uiView.scene?.rootNode)
        
        uiView.setNeedsDisplay()
        
        let (atoms, connects) = parsePdbFile(name: "DB01718")
        for atom in atoms {
            createAtom(uiView: uiView, atom: atom)
        }
        for connect in connects {
            let from = atoms.first(where: {$0.id == connect.from})
            for to in connect.to {
                let toAtom = atoms.first(where: {$0.id == to})
                createConnection(uiView: uiView, from: from!, to: toAtom!)
            }
        }
    }

    func setupLights(in rootNode: SCNNode?) {
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
            rootNode?.addChildNode(lightNode)
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
    
    func createAtom(uiView: SCNView, atom: Atom) {
        guard let color = color(for: atom.name) else { return }
        createSphere(uiView: uiView, radius: CGFloat(atom.radius), color: color, x: atom.x, y: atom.y, z: atom.z, atom: atom)
    }

    
    func createSphere(uiView: SCNView, radius: CGFloat, color: UIColor, x: Float, y: Float, z: Float, atom: Atom) {
        // add a sphere
        let sphere = SCNSphere(radius: radius)
        let sphereNode = SCNNode(geometry: sphere)
        sphereNode.position = SCNVector3(x: x, y: y, z: z)
        
        // Ajoute des métadonnées au nœud
        sphereNode.name = "Atom \(atom.id): \(atom.name)"
        
        // add a material to the sphere
        let material = SCNMaterial()
        material.diffuse.contents = color
        sphere.materials = [material]
        
        uiView.scene?.rootNode.addChildNode(sphereNode)
    }

    
    func color(for atomName: String) -> UIColor? {
        switch atomName {
        case "C": return .gray
        case "N": return .blue
        default: return .yellow
        }
    }
    
    func createConnection (uiView: SCNView, from: Atom, to: Atom) {
        guard let fromColor = color(for: from.name) else { return }
        
        // add coordinates of the first atom
        let fromNode = SCNNode()
        fromNode.position = SCNVector3(x: from.x, y: from.y, z: from.z)
        
        // add coordinates of the second atom
        let toNode = SCNNode()
        toNode.position = SCNVector3(x: to.x, y: to.y, z: to.z)
        
        // add a line between the two atoms
        makeCylinder(uiView: uiView, positionStart: fromNode.position, positionEnd: toNode.position, radius: 0.2, color: fromColor, transparency: 0.5)
        
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
