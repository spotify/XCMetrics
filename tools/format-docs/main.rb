require 'rubygems'
require 'nokogiri'

DOCS_PATH = File.expand_path("#{__dir__}/../../docs/generated")

Dir.foreach(DOCS_PATH) do |filename|
  next if filename == '.' || filename == '..' || !filename.end_with?('.html')

  doc = Nokogiri::HTML(open("#{DOCS_PATH}/#{filename}"))
  doc.css('a').each do |link|
    href = link.attributes['href']
    next unless href
    next unless href.value.match?(%r{^docs/.*\.md})

    href.value = href.value.downcase.gsub('%20', '-').gsub('docs/', '').gsub('.md', '.html')
  end

  doc.css('img').each do |img|
    src = img.attributes['src']
    next unless src
    next unless src.value.match?(%r{^docs/img/})

    src.value = src.value.gsub('docs/img/', 'img/')
  end

  doc.write_to(open("#{DOCS_PATH}/#{filename}", 'w'))
end
