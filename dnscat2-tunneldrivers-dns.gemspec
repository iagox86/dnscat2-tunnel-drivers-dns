lib = File.expand_path('lib', __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'dnscat2/tunnel_drivers/dns/version'

Gem::Specification.new do |spec|
  spec.name          = 'dnscat2-tunnel-drivers-dns'
  spec.version       = Dnscat2::TunnelDrivers::DNS::VERSION
  spec.authors       = ['iagox86']
  spec.email         = ['ron-git@skullsecurity.org']

  spec.summary       = 'A TunnelDriver for using dnscat2 over DNS'
  spec.description   = 'Implements the DNS protocol for dnscat2'
  spec.homepage      = 'https://github.com/iagox86/dnscat2-tunnel-drivers-dns'

  spec.files         = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^(test|spec|features)/})
  end
  spec.bindir        = 'exe'
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  spec.add_development_dependency 'bundler',   '~> 1.11'
  spec.add_development_dependency 'rake',      '~> 10.0'
  spec.add_development_dependency 'simplecov', '~> 0.14.1'
  spec.add_development_dependency 'test-unit', '~> 3.2.8'

  spec.add_dependency 'base32',     '~> 0.3.2'
  spec.add_dependency 'hexhelper',  '~> 0.0.2'
  spec.add_dependency 'nesser',     '~> 0.0.4'
  spec.add_dependency 'singlogger', '~> 0.0.0'
end
