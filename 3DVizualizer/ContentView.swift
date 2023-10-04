import SwiftUI
import SceneKit

struct ContentView: View {
    @State private var searchText: String = "16A"

    var body: some View {
        VStack {
            HStack {
                Text("Molécule de \(searchText)")
                    .font(.title)
                    .foregroundColor(.white)
                    .padding()
                    .background(.gray)
                    .cornerRadius(10)
                
                TextField("Recherche", text: $searchText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding([.leading, .trailing], 10)
                
                // button share
                Button(action: {
                    // share a screenshot of the molecule
                    print("Share button tapped")
                }) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.title)
                        .foregroundColor(.gray)
                        .padding()
                        .cornerRadius(50)
                }
            }
            SceneKitView(searchText: $searchText)
        }
    }
}

struct SceneKitView: UIViewRepresentable {
    @Binding var searchText: String

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
            print("handleTap function")
            guard let scnView = self.scnView else { return }
            
            // Attribut camera name
            if scnView.allowsCameraControl, scnView.pointOfView?.name == nil {
                scnView.pointOfView?.name = "userControlledCamera"
            }
            
            let p = gestureRecognize.location(in: scnView)
            let hitResults = scnView.hitTest(p, options: [:])
            
            if let cameraNode = scnView.scene?.rootNode.childNode(withName: "userControlledCamera", recursively: true) {
                scnView.pointOfView = cameraNode // Use own camera
                scnView.allowsCameraControl = false // Disable auto camera
                if hitResults.count > 0 {
                    handleAtomTap(hitResults[0], cameraNode: cameraNode)
                } else {
                    handleEmptySpaceTap(cameraNode: cameraNode)
                }
                scnView.allowsCameraControl = true
            }
        }
        
        func showInfoCapsule(message: String) {
            // Crée la capsule (UIView)
            let capsule = UILabel()
            capsule.text = message
            capsule.font = UIFont(name: "HelveticaNeue", size: 20)
            capsule.textColor = UIColor.black
            capsule.backgroundColor = UIColor.lightGray
            capsule.textAlignment = .center
            capsule.layer.cornerRadius = 10
            capsule.clipsToBounds = true

            // Positionne la capsule
            let capsuleSize = CGSize(width: 200, height: 50)
            capsule.frame = CGRect(x: 100, y: 100, width: capsuleSize.width, height: capsuleSize.height)
            
            // Ajoute la capsule à la vue
            scnView?.addSubview(capsule)
            
            // Fait disparaître la capsule après 3 secondes
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                capsule.removeFromSuperview()
            }
        }

        func handleAtomTap(_ result: SCNHitTestResult, cameraNode: SCNNode) {
            if let name = result.node.name {
                // Affiche le nom et l'ID de l'atome dans une fenêtre d'alerte
                showInfoCapsule(message: name)

                let atomPosition = result.node.position
                
                // Modification de la position de la caméra
                SCNTransaction.begin()
                SCNTransaction.animationDuration = 0.5
                cameraNode.position = SCNVector3(x: atomPosition.x, y: atomPosition.y, z: 10)
                SCNTransaction.commit()
            }
        }



        func handleEmptySpaceTap (cameraNode: SCNNode){
            // Ajustement de la position de la caméra si aucun atome n'est touché
            SCNTransaction.begin()
            SCNTransaction.animationDuration = 0.5
            cameraNode.position = SCNVector3(x: 0, y: 0, z: 50)
            SCNTransaction.commit()
        }

        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
            return true
        }
    }

    // create the scene view
    func makeUIView(context: Context) -> SCNView {
        let sceneView = SCNView()
        sceneView.backgroundColor = UIColor(white: 0.9, alpha: 1)
        sceneView.scene = SCNScene()
        sceneView.allowsCameraControl = true
        context.coordinator.scnView = sceneView
        
        let cameraNode = SCNNode()
        cameraNode.camera = SCNCamera()
        cameraNode.name = "userControlledCamera"
        cameraNode.position = SCNVector3(x: 0, y: 0, z: 50)
        sceneView.scene?.rootNode.addChildNode(cameraNode)
        sceneView.pointOfView = cameraNode
        
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
        let to: Int
        let weight: Int
    }

    func updateUIView(_ uiView: SCNView, context: Context) {
        context.coordinator.scnView = uiView
        
        if (searchText.count) == 0 {
            uiView.scene?.rootNode.enumerateChildNodes { (node, stop) in
                node.removeFromParentNode()
            }
        }
        // init camera
        var cameraNode = uiView.scene?.rootNode.childNode(withName: "cameraNode", recursively: false)
        
        if (cameraNode == nil) {
            cameraNode = SCNNode()
            cameraNode?.camera = SCNCamera()
            cameraNode?.name = "cameraNode"
            uiView.scene?.rootNode.addChildNode(cameraNode!)
        }
        
        if uiView.allowsCameraControl, uiView.pointOfView?.name == nil {
            uiView.pointOfView?.name = "userControlledCamera"
        }
        
        print("View initiale lors de l'update de la vue: \(uiView.pointOfView?.name ?? "")")
        
        // add camera position
        cameraNode?.position = SCNVector3(x: 0, y: 0, z: 50)
        
        // Light positions
        setupLights(in: uiView.scene?.rootNode)
        
        uiView.setNeedsDisplay()
        
        getSdfFile(moleculeCode: searchText) { atoms, connects in
            for atom in atoms {
                self.createAtom(uiView: uiView, atom: atom)
            }
            for connect in connects {
                if let from = atoms.first(where: {$0.id == connect.from}) {
                    if let to = atoms.first(where: {$0.id == connect.to}) {
                        self.createConnection(uiView: uiView, from: from, to: to)
                    }
                }
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
            lightNode.light?.intensity = 2000
            lightNode.light?.color = UIColor(white: 0.5, alpha: 1)
            lightNode.position = position
            rootNode?.addChildNode(lightNode)
        }
    }
    
    
    func getSdfFile(moleculeCode: String, completion: @escaping ([Atom], [Connect]) -> Void) {
        let dispatchGroup = DispatchGroup()
        dispatchGroup.enter()
        
        var atoms: [Atom] = []
        var connects: [Connect] = []
        
        let urlString = "https://files.rcsb.org/ligands/view/\(moleculeCode)_ideal.sdf"
        guard let url = URL(string: urlString) else { return }
        
        URLSession.shared.dataTask(with: url) { data, response, error in
            defer { dispatchGroup.leave() }
            
            guard let data = data else { return }
            let sdfString = String(data: data, encoding: .utf8) ?? ""
            
            // Ici, tu peux appeler ta fonction de parsing existante
            let (fetchedAtoms, fetchedConnects) = self.parseSdfFile(contents: sdfString) 
            atoms = fetchedAtoms
            connects = fetchedConnects
        }.resume()
        
        dispatchGroup.notify(queue: .main) {
            completion(atoms, connects)
        }
    }

    func parseSdfFile (contents: String) -> ([Atom], [Connect]){
        var atoms: [Atom] = []
        var connects: [Connect] = []
        do {
//            guard let filePath = Bundle.main.path(forResource: name, ofType: "sdf") else {
//                print("Fichier .sdf introuvable")
//                return ([], [])
//            }
//            let contents = try String(contentsOfFile: filePath)
            let lines = contents.split(separator: "\n")
            var isAtomSection = false
            var isConnectSection = false
            var atomCount = 0
            var connectCount = 0
            for line in lines {
                if line.contains("V2000") {
                    let counts = line.split(separator: " ")
                    atomCount = Int(counts[0]) ?? 0
                    connectCount = Int(counts[1]) ?? 0
                    isAtomSection = true
                    continue
                }
                if isAtomSection && atomCount > 0 {
                    let words = line.split(separator: " ", maxSplits: 10, omittingEmptySubsequences: true)
                    let x = Float(words[0]) ?? 0.0
                    let y = Float(words[1]) ?? 0.0
                    let z = Float(words[2]) ?? 0.0
                    let name = String(words[3])
                    atoms.append(Atom(id: atoms.count + 1, name: name, radius: 0.3, x: x, y: y, z: z))
                    atomCount -= 1
                    if atomCount == 0 {
                        isAtomSection = false
                        isConnectSection = true
                    }
                    continue
                }
                if isConnectSection && connectCount > 0 {
                    let words = line.split(separator: " ", maxSplits: 4, omittingEmptySubsequences: true)
                    let from = Int(words[0]) ?? 0
                    let to = Int(words[1]) ?? 0
                    let weight = Int(words[2]) ?? 0
                    connects.append(Connect(from: from, to: to, weight: weight))
                    connectCount -= 1
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
        
        // add metadatas
        sphereNode.name = "Atom \(atom.id): \(atom.name)"
        
        // add a material to the sphere
        let material = SCNMaterial()
        material.diffuse.contents = color
        sphere.materials = [material]
                
        uiView.scene?.rootNode.addChildNode(sphereNode)
    }

    func color(for atomName: String) -> UIColor? {
        switch atomName {
            case "H": return .white
            case "C": return .black
            case "N": return .blue
            case "O": return .red
            case "F", "Cl": return .green
            case "Br": return .brown
            case "I": return .purple
            case "He", "Ne", "Ar", "Xe", "Kr": return .cyan
            case "P": return .orange
            case "S": return .yellow
            case "B": return .magenta
            case "Li", "Na", "K", "Rb", "Cs", "Fr": return .systemTeal
            case "Be", "Mg", "Ca", "Sr", "Ba", "Ra": return .systemIndigo
            case "Ti", "Zr", "Hf", "Rf": return .systemPink
            case "V", "Nb", "Ta", "Db": return .systemPurple
            case "Cr", "Mo", "W", "Sg": return .systemOrange
            case "Mn", "Tc", "Re", "Bh": return .systemYellow
            case "Fe", "Ru", "Os", "Hs": return .systemGreen
            case "Co", "Rh", "Ir", "Mt": return .systemBlue
            case "Ni", "Pd", "Pt", "Ds": return .systemRed
            case "Cu", "Ag", "Au", "Rg": return .systemGray
            case "Zn", "Cd", "Hg", "Cn": return .systemBrown
            case "Al", "Ga", "In", "Tl", "Nh": return .systemTeal
            case "Si", "Ge", "Sn", "Pb", "Fl": return .systemIndigo
            case "As", "Sb", "Bi", "Mc": return .systemPink
            case "Se", "Te", "Po", "Lv": return .systemPurple
            case "At", "Ts", "Og": return .systemOrange
            default: return .yellow
        }
    }
    
    func createConnection (uiView: SCNView, from: Atom, to: Atom) {
        guard let fromColor = color(for: from.name) else { return }
        guard let toColor = color(for: to.name) else { return }
        print ("from: \(from.id) to: \(to.id)")
        // add coordinates of the first atom
        let fromNode = SCNNode()
        fromNode.position = SCNVector3(x: from.x, y: from.y, z: from.z)
        
        // add coordinates of the second atom
        let toNode = SCNNode()
        toNode.position = SCNVector3(x: to.x, y: to.y, z: to.z)
        
        // add line from A to half distance between A and B
        let halfDistance = SCNVector3((from.x + to.x) / 2, (from.y + to.y) / 2, (from.z + to.z) / 2)

        uiView.scene?.rootNode.addChildNode(CylinderLine(parent: uiView.scene!.rootNode, v1: fromNode.position, v2: halfDistance, radius: 0.2, radSegmentCount: 10, color: fromColor))
        uiView.scene?.rootNode.addChildNode(CylinderLine(parent: uiView.scene!.rootNode, v1: halfDistance, v2: toNode.position, radius: 0.2, radSegmentCount: 10, color: toColor))
    }
}

class   CylinderLine: SCNNode
{
    init( parent: SCNNode,//Needed to add destination point of your line
        v1: SCNVector3,//source
        v2: SCNVector3,//destination
        radius: CGFloat,//somes option for the cylinder
        radSegmentCount: Int, //other option
        color: UIColor )// color of your node object
    {
        super.init()
        //Calcul the height of our line
        let  height = v1.distance(receiver: v2)
        //set position to v1 coordonate
        position = v1
        //Create the second node to draw direction vector
        let nodeV2 = SCNNode()
        //define his position
        nodeV2.position = v2
        //add it to parent
        parent.addChildNode(nodeV2)
        //Align Z axis
        let zAlign = SCNNode()
        zAlign.eulerAngles.x = Float(Double.pi / 2)
        //create our cylinder
        let cyl = SCNCylinder(radius: radius, height: CGFloat(height))
        cyl.radialSegmentCount = radSegmentCount
        cyl.firstMaterial?.diffuse.contents = color
        //Create node with cylinder
        let nodeCyl = SCNNode(geometry: cyl )
        nodeCyl.position.y = -height/2
        zAlign.addChildNode(nodeCyl)
        //Add it to child
        addChildNode(zAlign)
        //set contrainte direction to our vector
        constraints = [SCNLookAtConstraint(target: nodeV2)]
    }
    override init() {
        super.init()
    }
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
}
private extension SCNVector3{
    func distance(receiver:SCNVector3) -> Float{
        let xd = receiver.x - self.x
        let yd = receiver.y - self.y
        let zd = receiver.z - self.z
        let distance = Float(sqrt(xd * xd + yd * yd + zd * zd))
        if (distance < 0){
            return (distance * -1)
        } else {
            return (distance)
        }
    }
}

// TODO :
// - Ajouter un bouton share pour partager l'image
