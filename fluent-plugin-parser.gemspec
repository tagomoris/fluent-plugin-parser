# -*- encoding: utf-8 -*-
Gem::Specification.new do |gem|
  gem.name          = "fluent-plugin-parser"
  gem.version       = "0.1.0"
  gem.authors       = ["TAGOMORI Satoshi"]
  gem.email         = ["tagomoris@gmail.com"]
  gem.description   = %q{parse data of specified field, and emit as new message, or as addtional field of message}
  gem.summary       = %q{fluentd plugin to parse single field, and re-emit it as message}
  gem.homepage      = "https://github.com/tagomoris/fluent-plugin-parser"

  gem.files         = `git ls-files`.split($\)
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.require_paths = ["lib"]

  gem.add_development_dependency "fluentd"
  gem.add_runtime_dependency "fluentd"
end
