# -*- encoding: utf-8 -*-

Gem::Specification.new do |s|
  s.name = %q{aim}
  s.version = "0.1.1"

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.authors = ["remi"]
  s.date = %q{2009-02-24}
  s.description = %q{Ruby gem for making AIM bots really easy to create}
  s.email = %q{remi@remitaylor.com}
  s.files = ["Rakefile", "VERSION.yml", "README.rdoc", "lib/aim.rb", "lib/aim", "lib/aim/net_toc.rb"]
  s.has_rdoc = true
  s.homepage = %q{http://github.com/remi/aim}
  s.rdoc_options = ["--inline-source", "--charset=UTF-8"]
  s.require_paths = ["lib"]
  s.rubygems_version = %q{1.3.1}
  s.summary = %q{Ruby gem for making AIM bots really easy to create}

  if s.respond_to? :specification_version then
    current_version = Gem::Specification::CURRENT_SPECIFICATION_VERSION
    s.specification_version = 2

    if Gem::Version.new(Gem::RubyGemsVersion) >= Gem::Version.new('1.2.0') then
    else
    end
  else
  end
end
