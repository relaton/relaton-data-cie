# frozen_string_literal: true

require 'English'
require 'mechanize'
require 'relaton_bib'

# @param hit [Nokogiri::HTML::Document]
# @param doc [Mechanize::Page]
# @return [Array<RelatonBib::DocumentIdentifier>]
def fetch_docid(hit, doc) # rubocop:disable Metrics/AbcSize,Metrics/MethodLength
  code = hit.at('h3/a').text.strip.sub(/\u25b9/, '')
  if code.match?(/^CIE/)
    add = doc.at('//hgroup/h2')&.text&.match(/Addendum\s1$/)
    code += " #{add}" if add
  elsif (pcode = doc.at('//dt[.="Product Code(s):"]/following-sibling::dd'))
    code = 'CIE ' + pcode.text.strip.match(/[^,]+/).to_s
  else
    code = 'CIE ' + code.match(/(?<=\()\w{2}\d+,.+(?=\))/).to_s.gsub(/,(?=\s)/, '').gsub(/,(?=\S)/, ' ')
  end
  docid = [RelatonBib::DocumentIdentifier.new(type: 'CIE', id: code)]
  # isbn = doc.at('//div[contains(@class, "field-name-field-isbn")]/div/div')
  isbn = doc.at('//dt[contains(.,"ISBN")]/following-sibling::dd')
  docid << RelatonBib::DocumentIdentifier.new(type: 'ISBN', id: isbn.text.strip) if isbn
  # doi = doc.at('//div[contains(@class, "field-name-field-doi")]/div/div')
  # docid << RelatonBib::DocumentIdentifier.new(type: 'DOI', id: doi.text.strip) if doi
  docid
end

# @param doc [Mechanize::Page]
# @return [RelatonBib::TypedTitleStringCollection, Array]
def fetch_title(doc)
  # doc.xpath('//hgroup/h2').map { |t| { content: t.text, language: 'en', script: 'Latn' } }
  t = doc.at('//hgroup/h2', '//hgroup/h1')
  return [] unless t

  RelatonBib::TypedTitleString.from_string t.text.strip
end

# @param doc [Mechanize::Page]
# @return [Array<RelatonBib::BibliographicDate>]
def fetch_date(doc)
  doc.xpath('//dt[.="Published:"]/following-sibling::dd[1]').map do |d|
    pd = d.text.strip
    on = pd.match?(/^\d{4}(?:[^-]|$)/) ? pd : Date.strptime(pd, '%m/%d/%Y').strftime('%Y-%m-%d')
    RelatonBib::BibliographicDate.new(type: 'published', on: on)
  end
end

# @param doc [Mechanize::Page]
# @return [String]
def fetch_edition(doc)
  doc.at('//dt[.="Edition:"]/following-sibling::dd')&.text&.match(/^\d+(?=th)/)&.to_s
end

# @param doc [Mechanize::Page]
# @return [Array<Hash>]
def fetch_relation(doc) # rubocop:disable Metrics/AbcSize,Metrics/MethodLength
  doc.xpath('//section[@class="history"]/ol/li[not(contains(@class,"selected-product"))]').map do |rel|
    ref = rel.at('a')
    url = 'https://www.techstreet.com' + ref[:href]
    title = RelatonBib::TypedTitleString.from_string ref.at('p/span[@class="title"]').text
    did = ref.at('h3').text
    docid = [RelatonBib::DocumentIdentifier.new(type: 'CIE', id: did)]
    on = ref.at('p/time')
    date = [RelatonBib::BibliographicDate.new(type: 'published', on: on[:datetime])]
    link = [RelatonBib::TypedUri.new(type: 'src', content: url)]
    bibitem = RelatonBib::BibliographicItem.new docid: docid, title: title, link: link, date: date
    type = ref.at('//li/i[contains(@class,"historical")]') ? 'updates' : 'updatedBy'
    { type: type, bibitem: bibitem }
  end
end

# @param url [String]
# @return [Array<RelatonBib::TypedUri>]
def fetch_link(url)
  [RelatonBib::TypedUri.new(type: 'src', content: url)]
end

# @param doc [Mechanize::Page]
# @return [Array<RelatonBib::FormattedString>]
def fetch_abstract(doc)
  content = doc.at('//div[contains(@class,"description")]')&.text&.strip
  return [] if content.nil? || content.empty?

  [RelatonBib::FormattedString.new(content: content, language: 'en', script: 'Latn')]
end

# @param doc [Mechanize::Page]
# @return [Array<Hash>]
def fetch_contributor(doc) # rubocop:disable Metrics/AbcSize,Metrics/MethodLength
  authors = doc.xpath('//hgroup/p[not(@class="pub_date")]').text
  # .split(/\s?,(?!\sand\s)|\sand\s|(?<=\w{2})\s(?!\w{2})|\.\s(?=\w{2})(?!and\s)/).each_slice(2).map do |p|
  contribs = []
  until authors.empty?
    /^(?<sname1>[^\s,]+)(,?\s(?<sname2>[\w-]{2,}))?
     (,?\s(?<fname>[\w-]{2,})(?!,\s?\s\w\.))?
     ((\s?,\s?|\s)(?<init>(\w\.[\s-]?)+))?
     ((,\s?|\s|(?<=\s))(and\s)?)?/x =~ authors
    authors.sub! $LAST_MATCH_INFO.to_s, ''
    sname = [sname1, sname2].compact.join ' '
    surname = RelatonBib::LocalizedString.new sname, 'en', 'Latn'
    initial = (init&.strip || '').split(/\.(?:-|\s)?/).map { |int| RelatonBib::LocalizedString.new(int, 'en', 'Latn') }
    forename = fname ? [RelatonBib::LocalizedString.new(fname, 'en', 'Latn')] : []
    fullname = RelatonBib::FullName.new surname: surname, forename: forename, initial: initial
    person = RelatonBib::Person.new name: fullname
    contribs << { entity: person, role: [{ type: 'author' }] }
  end
  org = RelatonBib::Organization.new(
    name: "Commission Internationale de L'Eclairage", abbreviation: 'CIE', url: 'cie.co.at'
  )
  contribs << { entity: org, role: [{ type: 'publisher' }] }
end

# @param bib [RelatonItu::ItuBibliographicItem]
def write_file(bib)
  id = bib.docidentifier[0].id.gsub(%r{[\/\s]}, '_')
  file = "data/#{id}.yaml"
  if File.exist? file
    warn "File #{file} exists. Docid: #{bib.docidentifier[0].id}"
    warn "Link: #{bib.link.detect { |l| l.type == 'src' }.content}"
  else
    File.write file, bib.to_hash.to_yaml, encoding: 'UTF-8'
  end
end

# @param hit [Nokogiri::HTML::Element]
# @param agent [Mechanize]
def parse_page(hit, agent) # rubocop:disable Metrics/AbcSize,Metrics/MethodLength
  url = 'https://www.techstreet.com' + hit.at('h3/a')[:href]
  doc = time_req { agent.get url }
  item = RelatonBib::BibliographicItem.new(
    type: 'standard', docid: fetch_docid(hit, doc), title: fetch_title(doc), link: fetch_link(url),
    abstract: fetch_abstract(doc), date: fetch_date(doc), edition: fetch_edition(doc),
    contributor: fetch_contributor(doc), relation: fetch_relation(doc), language: ['en'],
    script: ['Latn'], doctype: 'document'
  )
  write_file item
rescue => e # rubocop:disable Style/RescueStandardError
  warn 'Document: ' + url
  warn e.message
  warn e.backtrace
end

# @param agent [Mechanize]
# #param url [String]
# @param workers [RelatonBib::WorkersPool]
def html_index(agent, url) # , workers)
  result = time_req { agent.get url }
  # result.xpath('//tr/td').reject { |hit| hit.at('a').text.strip.empty? }.each { |hit| workers << hit }
  result.xpath('//li[@data-product]').each { |hit| parse_page hit, agent } # workers << hit }
  np = result.at '//a[@class="next_page"]'
  html_index agent, 'https://www.techstreet.com' + np[:href] if np # , workers if np
end

def time_req
  t1 = Time.now
  result = yield
  t = 1 - (Time.now - t1)
  sleep t if t.positive?
  result
end

agent = Mechanize.new
# workers = RelatonBib::WorkersPool.new 2
# url = 'https://cie.co.at/publications'
url = 'https://www.techstreet.com/cie/searches/31156444?page=1&per_page=100'
# workers.worker do |hit|
#   begin
#     parse_page(hit, agent)
#   rescue => e # rubocop:disable Style/RescueStandardError
#     warn e.message
#     warn e.backtrace
#   end
# end
t1 = Time.now
puts "Started at: #{t1}"

html_index agent, url # , workers
# index = agent.get 'https://www.techstreet.com/cie/searches/31156444?page=1&per_page=100'
# hit = index.at '//li[@data-product="2078723"]'
# parse_page hit, agent

# workers.end
# workers.result

t2 = Time.now
puts "Stopped at: #{t2}"
puts "Done in: #{(t2 - t1).round} sec."
