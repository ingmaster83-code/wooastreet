require 'json'

module Jekyll
  class StreetPageGenerator < Generator
    safe true
    priority :normal

    def generate(site)
      streets = site.data['streets']
      return unless streets&.any?

      Jekyll.logger.info "StreetGenerator:", "#{streets.size}개 페이지 생성 중..."

      streets.each do |street|
        same_region = streets
          .select { |s| s['region'] == street['region'] && s['slug'] != street['slug'] }
          .first(8)
          .map { |s| { 'slug' => s['slug'], 'name' => s['streetName'], 'city' => s['city'], 'themeLabel' => s['themeLabel'], 'themeIcon' => s['themeIcon'], 'image' => s['image'] } }

        same_theme = []
        if street['theme'] != 'etc'
          same_theme = streets
            .select { |s| s['theme'] == street['theme'] && s['slug'] != street['slug'] }
            .first(8)
            .map { |s| { 'slug' => s['slug'], 'name' => s['streetName'], 'region' => s['region'], 'city' => s['city'], 'image' => s['image'] } }
        end

        # 이전/다음: 같은 지역 내에서 이름 순 정렬 후 순환
        region_ordered = streets
          .select { |s| s['region'] == street['region'] }
          .sort_by { |s| s['streetName'].to_s }
        idx = region_ordered.index { |s| s['slug'] == street['slug'] }
        prev_street = nil
        next_street = nil
        if idx && region_ordered.size > 1
          p = region_ordered[(idx - 1) % region_ordered.size]
          n = region_ordered[(idx + 1) % region_ordered.size]
          prev_street = { 'slug' => p['slug'], 'name' => p['streetName'] }
          next_street = { 'slug' => n['slug'], 'name' => n['streetName'] }
        end

        site.pages << StreetPage.new(site, street, same_region, same_theme, prev_street, next_street)
      end

      by_region = streets.group_by { |s| s['region'] }
      by_region.each do |region, region_streets|
        slug = region_streets.first['regionSlug']
        site.pages << RegionPage.new(site, region, slug, region_streets)
      end

      site.pages << SearchIndexPage.new(site, streets)

      Jekyll.logger.info "StreetGenerator:", "완료 (#{streets.size}개)"
    end
  end

  class StreetPage < Page
    def initialize(site, street, same_region, same_theme, prev_street, next_street)
      @site = site
      @base = site.source
      @dir  = "street/#{street['slug']}"
      @name = 'index.html'

      self.process(@name)
      self.read_yaml(File.join(@base, '_layouts'), 'street.html')
      self.data.merge!(street)
      self.data['layout']      = 'street'
      self.data['same_region'] = same_region
      self.data['same_theme']  = same_theme
      self.data['prev_street'] = prev_street
      self.data['next_street'] = next_street

      self.data['title'] = "#{street['streetName']} 위치·소개 | #{street['region']} #{street['city']} 가볼만한 거리"
      overview_short = (street['overview'] || '').to_s
      overview_short = overview_short[0, 80] unless overview_short.empty?
      self.data['description'] = "#{street['streetName']}(#{street['region']} #{street['city']}) 정보. #{overview_short}"
    end
  end

  class RegionPage < Page
    def initialize(site, region, slug, streets)
      @site = site
      @base = site.source
      @dir  = "region/#{slug}"
      @name = 'index.html'

      self.process(@name)
      self.read_yaml(File.join(@base, '_layouts'), 'region.html')
      self.data['layout']      = 'region'
      self.data['region']      = region
      self.data['region_slug'] = slug
      self.data['streets']     = streets
      self.data['title']       = "#{region} 이색거리·테마골목 총정리 | 가볼만한 곳 #{streets.size}곳"
      self.data['description'] = "#{region} 이색거리·테마골목 #{streets.size}곳 총정리! 위치와 소개를 한눈에 확인하세요."
    end
  end

  class SearchIndexPage < Page
    def initialize(site, streets)
      @site = site
      @base = site.source
      @dir  = ''
      @name = 'search_index.json'

      self.process(@name)
      self.data = { 'layout' => nil, 'sitemap' => false }

      index = streets.map do |s|
        {
          'slug' => s['slug'], 'name' => s['streetName'], 'region' => s['region'], 'city' => s['city'],
          'themeLabel' => s['themeLabel'], 'image' => s['image'],
        }
      end

      self.content = index.to_json
    end

    def output   = self.content
    def render(layouts, registers); end
  end
end
