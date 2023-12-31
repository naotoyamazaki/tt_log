# -*- encoding: utf-8 -*-
# stub: oauth2 1.4.11 ruby lib

Gem::Specification.new do |s|
  s.name = "oauth2".freeze
  s.version = "1.4.11"

  s.required_rubygems_version = Gem::Requirement.new(">= 0".freeze) if s.respond_to? :required_rubygems_version=
  s.metadata = { "bug_tracker_uri" => "https://gitlab.com/oauth-xx/oauth2/-/issues", "changelog_uri" => "https://gitlab.com/oauth-xx/oauth2/-/blob/v1.4.11/CHANGELOG.md", "documentation_uri" => "https://www.rubydoc.info/gems/oauth2/1.4.11", "funding_uri" => "https://liberapay.com/pboling", "homepage_uri" => "https://gitlab.com/oauth-xx/oauth2", "rubygems_mfa_required" => "true", "source_code_uri" => "https://gitlab.com/oauth-xx/oauth2/-/tree/v1.4.11", "wiki_uri" => "https://gitlab.com/oauth-xx/oauth2/-/wiki" } if s.respond_to? :metadata=
  s.require_paths = ["lib".freeze]
  s.authors = ["Peter Boling".freeze, "Erik Michaels-Ober".freeze, "Michael Bleigh".freeze]
  s.bindir = "exe".freeze
  s.date = "2022-09-16"
  s.description = "A Ruby wrapper for the OAuth 2.0 protocol built with a similar style to the original OAuth spec.".freeze
  s.email = ["peter.boling@gmail.com".freeze]
  s.homepage = "https://gitlab.com/oauth-xx/oauth2".freeze
  s.licenses = ["MIT".freeze]
  s.post_install_message = "\nYou have installed oauth2 version 1.4.11, which is EOL.\nNo further support is anticipated for the 1.4.x series.\n\nOAuth2 version 2 is released.\nThere are BREAKING changes, but most will not encounter them, and upgrading should be easy!\n\nWe have made two other major migrations:\n1. master branch renamed to main\n2. Github has been replaced with Gitlab\n\nPlease see:\n\u2022 https://gitlab.com/oauth-xx/oauth2#what-is-new-for-v20\n\u2022 https://gitlab.com/oauth-xx/oauth2/-/blob/main/CHANGELOG.md\n\u2022 https://groups.google.com/g/oauth-ruby/c/QA_dtrXWXaE\n\nPlease upgrade, report issues, and support the project! Thanks, |7eter l-|. l3oling\n\n".freeze
  s.required_ruby_version = Gem::Requirement.new(">= 1.9.0".freeze)
  s.rubygems_version = "3.4.10".freeze
  s.summary = "A Ruby wrapper for the OAuth 2.0 protocol.".freeze

  s.installed_by_version = "3.4.10" if s.respond_to? :installed_by_version

  s.specification_version = 4

  s.add_runtime_dependency(%q<faraday>.freeze, [">= 0.17.3", "< 3.0"])
  s.add_runtime_dependency(%q<jwt>.freeze, [">= 1.0", "< 3.0"])
  s.add_runtime_dependency(%q<multi_json>.freeze, ["~> 1.3"])
  s.add_runtime_dependency(%q<multi_xml>.freeze, ["~> 0.5"])
  s.add_runtime_dependency(%q<rack>.freeze, [">= 1.2", "< 4"])
  s.add_development_dependency(%q<addressable>.freeze, [">= 2"])
  s.add_development_dependency(%q<bundler>.freeze, [">= 1.16"])
  s.add_development_dependency(%q<rake>.freeze, [">= 12"])
  s.add_development_dependency(%q<rexml>.freeze, [">= 3"])
  s.add_development_dependency(%q<rspec>.freeze, [">= 3"])
  s.add_development_dependency(%q<rspec-block_is_expected>.freeze, [">= 0"])
  s.add_development_dependency(%q<rspec-pending_for>.freeze, [">= 0"])
  s.add_development_dependency(%q<rspec-stubbed_env>.freeze, [">= 0"])
  s.add_development_dependency(%q<rubocop-lts>.freeze, [">= 2.0.3", "~> 2.0"])
  s.add_development_dependency(%q<silent_stream>.freeze, [">= 0"])
end
