# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'EPUBChop/version'

Gem::Specification.new do |spec|
  spec.name          = "EPUBChop"
  spec.version       = EPUBChop::VERSION
  spec.authors       = ["Mehmet Celik"]
  spec.email         = ["mehmet@celik.be"]
  spec.description   = %q{Create EPUB previews}
  spec.summary       = %q{Removes unwanted content from an EPUB}
  spec.homepage      = "https://github.com/mehmetc/EPUBChop"
  spec.license       = "MIT"

  spec.files         = `git ls-files`.split($/)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.3"
  spec.add_development_dependency "rake"
  spec.add_development_dependency "rspec"
  spec.add_runtime_dependency "epubinfo_with_toc"
  spec.add_runtime_dependency "rubyzip", "~> 1.0"
  spec.add_runtime_dependency "nokogiri"
end
