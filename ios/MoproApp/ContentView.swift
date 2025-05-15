//
//  ContentView.swift
//  MoproApp
//
import SwiftUI
import moproFFI

func serializeOutputs(_ stringArray: [String]) -> [UInt8] {
    var bytesArray: [UInt8] = []
    let length = stringArray.count
    var littleEndianLength = length.littleEndian
    let targetLength = 32
    withUnsafeBytes(of: &littleEndianLength) {
        bytesArray.append(contentsOf: $0)
    }
    for value in stringArray {
        // TODO: should handle 254-bit input
        var littleEndian = Int32(value)!.littleEndian
        var byteLength = 0
        withUnsafeBytes(of: &littleEndian) {
            bytesArray.append(contentsOf: $0)
            byteLength = byteLength + $0.count
        }
        if byteLength < targetLength {
            let paddingCount = targetLength - byteLength
            let paddingArray = [UInt8](repeating: 0, count: paddingCount)
            bytesArray.append(contentsOf: paddingArray)
        }
    }
    return bytesArray
}

struct ContentView: View {
    @State private var textViewText = ""
    @State private var isCircomProveButtonEnabled = true
    @State private var isCircomVerifyButtonEnabled = false
    @State private var isHalo2roveButtonEnabled = true
    @State private var isHalo2VerifyButtonEnabled = false
    @State private var generatedCircomProof: CircomProof?
    @State private var circomPublicInputs: [String]?
    @State private var generatedHalo2Proof: Data?
    @State private var halo2PublicInputs: Data?
    @State private var isRSAPRAroveButtonEnabled = true
    @State private var isRSAVerifyButtonEnabled = false
    @State private var generatedRSAProof: Data?
    @State private var rsaInputs: [String]?
    private let zkeyPath = Bundle.main.path(forResource: "multiplier2_final", ofType: "zkey")!
    private let srsPath = Bundle.main.path(forResource: "plonk_fibonacci_srs.bin", ofType: "")!
    private let vkPath = Bundle.main.path(forResource: "plonk_fibonacci_vk.bin", ofType: "")!
    private let pkPath = Bundle.main.path(forResource: "plonk_fibonacci_pk.bin", ofType: "")!
    
    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "globe")
                .imageScale(.large)
                .foregroundStyle(.tint)
            Button("Prove Circom", action: runCircomProveAction).disabled(!isCircomProveButtonEnabled).accessibilityIdentifier("proveCircom")
            Button("Verify Circom", action: runCircomVerifyAction).disabled(!isCircomVerifyButtonEnabled).accessibilityIdentifier("verifyCircom")
            Button("Prove Halo2", action: runHalo2ProveAction).disabled(!isHalo2roveButtonEnabled).accessibilityIdentifier("proveHalo2")
            Button("Verify Halo2", action: runHalo2VerifyAction).disabled(!isHalo2VerifyButtonEnabled).accessibilityIdentifier("verifyHalo2")
            Button("Prove RSA", action: runRSAProveAction).disabled(!isRSAPRAroveButtonEnabled).accessibilityIdentifier("proveRSA")
            Button("Verify RSA", action: runRSAVerifyAction).disabled(!isRSAVerifyButtonEnabled).accessibilityIdentifier("verifyRSA")

            ScrollView {
                Text(textViewText)
                    .padding()
                    .accessibilityIdentifier("proof_log")
            }
            .frame(height: 200)
        }
        .padding()
    }
}

extension ContentView {
    func runCircomProveAction() {
        textViewText += "Generating Circom proof... "
        do {
            // Prepare inputs
            let a = 3
            let b = 5
            let c = a*b
            let input_str: String = "{\"b\":[\"5\"],\"a\":[\"3\"]}"

            // Expected outputs
            let outputs: [String] = [String(c), String(a)]

            let start = CFAbsoluteTimeGetCurrent()

            // Generate Proof
            let generateProofResult = try generateCircomProof(zkeyPath: zkeyPath, circuitInputs: input_str, proofLib: ProofLib.arkworks)
            assert(!generateProofResult.proof.a.x.isEmpty, "Proof should not be empty")
            assert(outputs == generateProofResult.inputs, "Circuit outputs mismatch the expected outputs")

            let end = CFAbsoluteTimeGetCurrent()
            let timeTaken = end - start

            // Store the generated proof and public inputs for later verification
            generatedCircomProof = generateProofResult.proof
            circomPublicInputs = generateProofResult.inputs

            textViewText += "\(String(format: "%.3f", timeTaken))s 1️⃣\n"

            isCircomVerifyButtonEnabled = true
        } catch {
            textViewText += "\nProof generation failed: \(error.localizedDescription)\n"
        }
    }
    
    func runCircomVerifyAction() {
        guard let proof = generatedCircomProof,
              let inputs = circomPublicInputs else {
            textViewText += "Proof has not been generated yet.\n"
            return
        }
        
        textViewText += "Verifying Circom proof... "
        do {
            let start = CFAbsoluteTimeGetCurrent()
            
            let isValid = try verifyCircomProof(zkeyPath: zkeyPath, proofResult: CircomProofResult(proof: proof, inputs: inputs), proofLib: ProofLib.arkworks)
            let end = CFAbsoluteTimeGetCurrent()
            let timeTaken = end - start
            
            assert(proof.a.x.count > 0, "Proof should not be empty")
            assert(inputs.count > 0, "Inputs should not be empty")
            
            print("Ethereum Proof: \(proof)\n")
            print("Ethereum Inputs: \(inputs)\n")
            
            if isValid {
                textViewText += "\(String(format: "%.3f", timeTaken))s 2️⃣\n"
            } else {
                textViewText += "\nProof verification failed.\n"
            }
            isCircomVerifyButtonEnabled = false
        } catch let error as MoproError {
            print("\nMoproError: \(error)")
        } catch {
            print("\nUnexpected error: \(error)")
        }
    }
    
    func runHalo2ProveAction() {
        textViewText += "Generating Halo2 proof... "
        do {
            // Prepare inputs
            var inputs = [String: [String]]()
            let out = 55
            inputs["out"] = [String(out)]
            
            let start = CFAbsoluteTimeGetCurrent()
            
            // Generate Proof
            let generateProofResult = try generateHalo2Proof(srsPath: srsPath, pkPath: pkPath, circuitInputs: inputs)
            assert(!generateProofResult.proof.isEmpty, "Proof should not be empty")
            assert(!generateProofResult.inputs.isEmpty, "Inputs should not be empty")

            
            let end = CFAbsoluteTimeGetCurrent()
            let timeTaken = end - start
            
            // Store the generated proof and public inputs for later verification
            generatedHalo2Proof = generateProofResult.proof
            halo2PublicInputs = generateProofResult.inputs
            
            textViewText += "\(String(format: "%.3f", timeTaken))s 1️⃣\n"
            
            isHalo2VerifyButtonEnabled = true
        } catch {
            textViewText += "\nProof generation failed: \(error.localizedDescription)\n"
        }
    }
    
    func runHalo2VerifyAction() {
        guard let proof = generatedHalo2Proof,
              let inputs = halo2PublicInputs else {
            textViewText += "Proof has not been generated yet.\n"
            return
        }
        
        textViewText += "Verifying Halo2 proof... "
        do {
            let start = CFAbsoluteTimeGetCurrent()
            
            let isValid = try verifyHalo2Proof(
              srsPath: srsPath, vkPath: vkPath, proof: proof, publicInput: inputs)
            let end = CFAbsoluteTimeGetCurrent()
            let timeTaken = end - start

            
            if isValid {
                textViewText += "\(String(format: "%.3f", timeTaken))s 2️⃣\n"
            } else {
                textViewText += "\nProof verification failed.\n"
            }
            isHalo2VerifyButtonEnabled = false
        } catch let error as MoproError {
            print("\nMoproError: \(error)")
        } catch {
            print("\nUnexpected error: \(error)")
        }
    }

    func runRSAProveAction() {
        textViewText += "Generating RSA proof... "

        guard let srsPath = Bundle.main.path(forResource: "zkemail_srs", ofType: "local") else {
            DispatchQueue.main.async {
                self.textViewText += "\nError: Could not find srs.local in app bundle.\n"
            }
            return
        }

        // Inputs from Prover.toml
        let inputs: [String] = [
            "0xad29e07d16a278de49a371b9760a27",
            "0x86311920cc0e17a3c20cdff4c56dbb",
            "0x863556c6c5247dd83668dd825716ae",
            "0xc247c960945f4485b46c33b87425ca",
            "0x7326463c5c4cd5b08e21b938d9ed9a",
            "0x4f89fe0c82da08a0259eddb34d0da1",
            "0x43a74e76d4e1bd2666f1591889af0d",
            "0x240f7b80f0ff29f4253ee3019f832d",
            "0xc6edd131fbaaf725fd423dac52b362",
            "0x85f9732679242163e8afff44f6104d",
            "0xd3c3bbcb1757013fd6fb80f31dd9a6",
            "0x9008633f15df440e6df6d21ee585a2",
            "0x324df3425ed256e283be5b6b761741",
            "0xc60c1302929bd0e07caa4aeff4e8fd",
            "0x600d804ff13ba8d0e1bc9508714212",
            "0x50f7e75e5751d7edd61167027926be",
            "0x0db41d39442023e1420a8a84fe81d9",
            "0xab",
        ]
        self.rsaInputs = inputs // Store for verification

        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let start = CFAbsoluteTimeGetCurrent()

                let proofData = try! proveRsaSimple(srsPath: srsPath, inputs: inputs)
                assert(!proofData.isEmpty, "Proof should not be empty")

                let end = CFAbsoluteTimeGetCurrent()
                let timeTaken = end - start

                DispatchQueue.main.async {
                    self.generatedRSAProof = proofData
                    self.textViewText += "\(String(format: "%.3f", timeTaken))s 1️⃣\n"
                    self.isRSAVerifyButtonEnabled = true
                    self.isRSAPRAroveButtonEnabled = false
                }
            } catch {
                DispatchQueue.main.async {
                    self.textViewText += "\nProof generation failed: \(error.localizedDescription)\n"
                }
            }
        }
    }

    func runRSAVerifyAction() {
        guard let proofData = generatedRSAProof else {
            textViewText += "Proof has not been generated yet.\n"
            return
        }

        guard let srsPath = Bundle.main.path(forResource: "zkemail_srs", ofType: "local") else {
            DispatchQueue.main.async {
                self.textViewText += "\nError: Could not find srs.local in app bundle.\n"
            }
            return
        }

        textViewText += "Verifying RSA proof... "

        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let start = CFAbsoluteTimeGetCurrent()

                let isValid = try! verifyRsaSimple(srsPath: srsPath, proof: proofData)
                let end = CFAbsoluteTimeGetCurrent()
                let timeTaken = end - start

                DispatchQueue.main.async {
                    if isValid {
                        self.textViewText += "\(String(format: "%.3f", timeTaken))s 2️⃣\n"
                    } else {
                        self.textViewText += "\nProof verification failed.\n"
                    }
                    self.isRSAVerifyButtonEnabled = false
                    self.isRSAPRAroveButtonEnabled = true
                }
            } catch let error as MoproError {
                DispatchQueue.main.async {
                    self.textViewText += "\nMoproError: \(error)\n"
                    self.isRSAVerifyButtonEnabled = false
                }
            } catch {
                DispatchQueue.main.async {
                    self.textViewText += "\nUnexpected error: \(error.localizedDescription)\n"
                    self.isRSAVerifyButtonEnabled = false
                }
            }
        }
    }
}

