spec = Gem::Specification.new do |s|
	s.name = 'galgen'
	s.version = '0.1'
	s.summary = 'Gallery Generator'
	s.description = 'Static HTML gallery generator'
	s.add_dependency('builder', '>= 2.0')
	s.add_dependency('RedCloth', '>= 1.0')
	s.add_dependency('tilt', '>= 1.0')
	s.files = ['bin/galgen', 'COPYING', 'README.textile']
	s.has_rdoc = false
	s.author = "Voker57"
	s.email = "voker57@gmail.com"
	s.homepage = "http://bitcheese.net/wiki/code/galgen"
	s.default_executable = 'galgen'
	s.executables = ['galgen']
end