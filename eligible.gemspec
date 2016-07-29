# -*- encoding: utf-8 -*-
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'eligible/version'

Gem::Specification.new do |gem|
  gem.name          = "eligible"
  gem.version       = Eligible::VERSION
  gem.authors       = ["Katelyn Gleaon", "Rodrigo Dominguez", "Andry Brett"]
  gem.email         = ["k@eligibleapi.com", "rod@eligibleapi.com", "andy@andybrett.com"]
  gem.description   = 'Eligible is a developer-friendly way to process health care eligibility checks. Learn more at https://www.eligibleapi.com'
  gem.summary       = 'Ruby wrapper for the Eligible API'
  gem.homepage      = "https://www.eligibleapi.com/"
  gem.license       = "MIT"

  gem.files         = `git ls-files`.split($/)
  gem.test_files    = `git ls-files -- test/*`.split("\n")
  gem.require_paths = ["lib"]

  gem.add_development_dependency('mocha')
  gem.add_development_dependency('shoulda')
  gem.add_development_dependency('test-unit')
  gem.add_development_dependency('rake')

  gem.add_dependency('rest-client', '~> 1.8.0')
  gem.add_dependency('multi_json', '~> 1.7')
end
