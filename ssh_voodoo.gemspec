# -*- encoding: utf-8 -*-

$LOAD_PATH.push File.expand_path("../lib", __FILE__)

Gem::Specification.new do |s|
  s.name        = "ssh_voodoo"
  s.version     = "0.0.1"
  s.platform    = Gem::Platform::RUBY
  s.authors     = ["Darren Dao"]
  s.email       = ["darrendao@gmail.com"]
  s.homepage    = "https://github.com/darrendao/ssh_voodoo"
  s.summary     = %q{Ruby script to help with the task of running commands on remote machines via ssh.}
  s.description = %q{Ruby script to help with the task of running commands on remote machines via ssh. It supports password caching and ssh keys. You can specify the remote hosts on the cmd option, or via a file.}

  s.add_dependency 'net-ssh', '~> 2.3'
  s.add_development_dependency 'yard', '~> 0.7'

  s.files            = `git ls-files`.split("\n")
  s.executables      = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths    = ["lib"]
  s.extra_rdoc_files = ["README.md"]
end

