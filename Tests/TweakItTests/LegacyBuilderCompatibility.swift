// Compile-only check: the pre-1.1 consumer pattern must still build.
import TweakIt

@TweakDefinitionBuilder
func legacyConsumerHelper() -> [TweakDefinition] {
    TweakDefinition("alpha", default: 1.0, range: 0.0...1.0)
    TweakDefinition("beta", default: false)
}
