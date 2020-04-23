require_relative 'lib/staticPodGenerator/version'

Gem::Specification.new do |spec|
  spec.name          = "staticPodGenerator"
  spec.version       = StaticPodGenerator::VERSION
  spec.authors       = ["刘博"]
  spec.email         = ["bo.liu@ly.com"]
  spec.licenses      = ['Nonstandard']

  spec.summary       = %q{生成指定pod对应的静态库pod}
  spec.homepage      = "http://git.17usoft.com/RubyGems/staticPodGenerator"
  spec.required_ruby_version = Gem::Requirement.new(">= 2.3.0")

  spec.files         = Dir["lib/**/*.rb"] + ["bin/staticPodGenerator"] + ["resources/PodfileTemplate"]
  spec.executables   = ["staticPodGenerator"]
  spec.require_paths = ["lib"]

  spec.add_dependency "cocoapods-rome2", '~> 1.0.0'
  spec.add_dependency "cocoapods", '~> 1.9.1'
end
