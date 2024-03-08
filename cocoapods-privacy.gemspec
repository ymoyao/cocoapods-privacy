# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'cocoapods-privacy/gem_version.rb'

Gem::Specification.new do |spec|
  spec.name          = 'cocoapods-privacy'
  spec.version       = CocoapodsPrivacy::VERSION
  spec.authors       = ['youhui']
  spec.email         = ['developer_yh@163.com']
  spec.description   = %q{A short description of cocoapods-privacy.}
  spec.summary       = %q{A longer description of cocoapods-privacy.}
  spec.homepage      = 'https://github.com/ymoyao/cocoapods-privacy'
  spec.license       = 'MIT'

  spec.required_ruby_version = Gem::Requirement.new(">= 2.7.0")
  spec.files = Dir["lib/**/*.rb","spec/**/*.rb"] + %w{README.md LICENSE.txt }
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ['lib']

  spec.add_development_dependency 'bundler', '~> 1.3'
  spec.add_development_dependency 'rake'
end
