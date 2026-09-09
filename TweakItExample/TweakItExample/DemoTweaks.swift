//
//  DemoTweaks.swift
//  TweakItDemo
//
//  TweakStore DSL definition for all shader parameters.
//

import TweakIt
import Foundation

// MARK: - Shader Type

enum ShaderType: String, CaseIterable {
    case plasma
    case aurora
    case marble
    case voronoi

    var name: String {
        switch self {
        case .plasma:  return "Plasma"
        case .aurora:  return "Aurora"
        case .marble:  return "Marble"
        case .voronoi: return "Voronoi"
        }
    }

    var icon: String {
        switch self {
        case .plasma:  return "waveform"
        case .aurora:  return "sparkles"
        case .marble:  return "water.waves"
        case .voronoi: return "hexagon"
        }
    }
}

// MARK: - Store Definition

enum DemoTweaks {
    static let store = TweakStore {
        // MARK: Plasma
        TweakCategory("Plasma", icon: "waveform") {
            TweakSection("Motion") {
                TweakDefinition("speed", default: 1.0, range: 0.0...5.0)
                TweakDefinition("scale", default: 3.0, range: 0.5...10.0)
            }
            // Groups and descriptions. Note the keys are untouched by the grouping —
            // "Plasma.Color.saturation" reads the same whether or not it sits in a group.
            TweakSection("Color") {
                TweakDefinition("waveCount", default: 4, range: 1.0...8.0,
                                description: "interfering waves summed per pixel")

                TweakGroup("Field") {
                    TweakDefinition("distortion", default: 0.5, range: 0.0...2.0,
                                    description: "warps the field before it's shaded")
                }

                TweakGroup("Palette") {
                    TweakDefinition("saturation", default: 0.7, range: 0.0...1.0)
                    TweakDefinition("brightness", default: 0.5, range: 0.0...1.0)
                    TweakDefinition("palette", default: "neon", options: ["lava", "ocean", "neon", "pastel", "mono"],
                                    description: "colour ramp the field is mapped through")
                }
            }
        }

        // MARK: Aurora
        TweakCategory("Aurora", icon: "sparkles") {
            TweakSection("Motion") {
                TweakDefinition("speed", default: 0.8, range: 0.0...3.0)
                TweakDefinition("amplitude", default: 0.3, range: 0.0...1.0)
            }
            TweakSection("Shape") {
                TweakDefinition("layers", default: 4, range: 1.0...8.0)
                TweakDefinition("verticalCenter", default: 0.4, range: 0.0...1.0)
                TweakDefinition("bandWidth", default: 0.15, range: 0.02...0.5)
            }
            TweakSection("Style") {
                TweakDefinition("brightness", default: 0.8, range: 0.0...1.5)
                TweakDefinition("palette", default: "arctic", options: ["arctic", "solar", "cosmic", "fire"])
                TweakDefinition("starField", default: true)
            }
        }

        // MARK: Marble
        TweakCategory("Marble", icon: "water.waves") {
            TweakSection("Motion") {
                TweakDefinition("speed", default: 0.5, range: 0.0...3.0)
                TweakDefinition("turbulence", default: 1.0, range: 0.0...3.0)
            }
            TweakSection("Color") {
                TweakDefinition("octaves", default: 5, range: 1.0...8.0)
                TweakDefinition("displacement", default: 1.5, range: 0.0...5.0)
                TweakDefinition("bandFrequency", default: 5.0, range: 1.0...20.0)
                TweakDefinition("colorSeparation", default: 0.1, range: 0.0...0.5)
                TweakDefinition("palette", default: "marble", options: ["marble", "ink", "oil", "candy"])
            }
        }

        // MARK: Voronoi
        TweakCategory("Voronoi", icon: "hexagon") {
            TweakSection("Cells") {
                TweakDefinition("cellDensity", default: 5.0, range: 2.0...15.0)
                TweakDefinition("morphSpeed", default: 0.8, range: 0.0...3.0)
            }
            TweakSection("Edges") {
                TweakDefinition("edgeWidth", default: 0.05, range: 0.0...0.3)
                TweakDefinition("edgeGlow", default: 0.5, range: 0.0...2.0)
            }
            TweakSection("Style") {
                TweakDefinition("fillMode", default: "gradient", options: ["solid", "gradient", "wireframe"])
                TweakDefinition("palette", default: "crystal", options: ["crystal", "neon", "earth", "mono"])
                TweakDefinition("invert", default: false)
            }
        }

        // MARK: App
        TweakCategory("App", icon: "app.badge") {
            TweakSection("Panel") {
                TweakDefinition("useFloatingButton", default: false)
            }
        }

        // MARK: Actions
        TweakCategory("Actions", icon: "bolt.fill") {
            TweakSection("Presets") {
                TweakDefinition("Reset All to Defaults", action: {
                    print("🔄 Reset all tweaks to defaults")
                })
                TweakDefinition("Apply Neon Preset", action: {
                    print("🎨 Applied neon preset")
                })
                TweakDefinition("Apply Calm Preset", action: {
                    print("🌊 Applied calm preset")
                })
            }
            TweakSection("Export") {
                TweakDefinition("Copy Config to Clipboard", action: {
                    print("📋 Config copied to clipboard")
                })
                TweakDefinition("Share Screenshot", action: {
                    print("📤 Sharing screenshot")
                })
            }
        }

        // MARK: Post-Processing
        TweakCategory("Post-Processing", icon: "camera.filters") {
            TweakSection("Film Grain") {
                TweakDefinition("enabled", default: false)

                TweakGroup("Grain") {
                    TweakDefinition("amount", default: 0.15, range: 0.0...0.5,
                                    description: "opacity of the grain overlay")
                    TweakDefinition("size", default: 1.5, range: 0.5...4.0,
                                    description: "grain cell size, in pixels")
                }

                // Back outside the group: a second unnamed run, rendered headerless under it.
                TweakDefinition("animated", default: true,
                                description: "resample the grain every frame")
            }
            TweakSection("Vignette") {
                TweakDefinition("enabled", default: false)
                TweakDefinition("strength", default: 0.5, range: 0.0...1.5)
                TweakDefinition("radius", default: 0.7, range: 0.2...1.5)
            }
        }
    }
}
