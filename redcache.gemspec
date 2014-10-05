# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'redcache/version'

Gem::Specification.new do |spec|
  spec.name          = "redcache"
  spec.version       = Redcache::VERSION
  spec.authors       = ["Neil Middleton"]
  spec.email         = ["neil@neilmiddleton.com"]
  spec.summary       = %q{A gem for caching values in redis and encrypting them}
  spec.description   = %q{A wrapper for Redis, for caching and encryption with Fernet}
  spec.homepage      = "http://www.neilmiddleton.com"
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0")
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.7"
  spec.add_development_dependency "rake", "~> 10.0"

  spec.add_dependency "fernet", "~> 2.1"
  spec.add_dependency "redis", "~> 3.1"
  spec.add_dependency "multi_json", "~> 1.10"
end
