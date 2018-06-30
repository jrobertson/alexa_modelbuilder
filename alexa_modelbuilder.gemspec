Gem::Specification.new do |s|
  s.name = 'alexa_modelbuilder'
  s.version = '0.3.0'
  s.summary = 'Builds an Alexa Skills Interaction Model and optionally ' + 
      'an Alexa Skills manigest in JSON format from plain text'
  s.authors = ['James Robertson']
  s.files = Dir['lib/alexa_modelbuilder.rb']
  s.signing_key = '../privatekeys/alexa_modelbuilder.pem'
  s.add_runtime_dependency('lineparser', '~> 0.1', '>=0.1.19')
  s.cert_chain  = ['gem-public_cert.pem']
  s.license = 'MIT'
  s.email = 'james@jamesrobertson.eu'
  s.homepage = 'https://github.com/jrobertson/alexa_modelbuilder'
end
