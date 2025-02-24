SitemapGenerator::Sitemap.default_host = "https://www.ttlog.jp"
SitemapGenerator::Sitemap.create do
  add root_path, changefreq: 'daily'
  add terms_of_service_path, changefreq: 'monthly'
  add privacy_policy_path, changefreq: 'monthly'

  add login_path, changefreq: 'monthly'

  MatchInfo.find_each do |match_info|
    add match_info_path(match_info), lastmod: match_info.updated_at
  end
end
