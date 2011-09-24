# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "apocalypse-client/version"

Gem::Specification.new do |s|
  s.name        = "apocalypse-client"
  s.version     = Apocalypse::Client::VERSION
  s.authors     = ["Ariejan de Vroom"]
  s.email       = ["ariejan@ariejan.net"]
  s.homepage    = ""
  s.summary     = %q{Watch out for the apocalypse}
  s.description = %q{Server monitoring made easy}

  s.rubyforge_project = "apocalypse-client"

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]

  s.add_dependency("json", ["~> 1.5.3"])
  s.add_dependency("trollop", ["~> 1.16.2"])

  s.add_development_dependency("rspec", ["~> 2.6.0"])
end
