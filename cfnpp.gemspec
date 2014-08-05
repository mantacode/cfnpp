Gem::Specification.new do |s|
  s.name = 'cfnpp'
  s.version = '0.3.11'
  s.date = '2014-08-01'
  s.summary = 'cfnpp'
  s.description = 'cfnpp',
  s.authors = ["Michael Bruce", "Stephen J. Smith"]
  s.email = 'mbruce@manta.com'
  s.files += Dir['lib/**/*.rb']
  s.add_runtime_dependency 'aws-sdk'
  s.add_runtime_dependency 'json'
  s.add_runtime_dependency 'awesome_print'
  s.add_runtime_dependency 'travis'
  s.add_runtime_dependency 'dogapi'
  s.add_runtime_dependency 'ploy'
  s.executables << 'cfnpp'
end
