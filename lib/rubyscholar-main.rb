require 'nokogiri'
require 'open-uri'
require 'rubyscholar-version'
require 'active_support/inflector'
require 'json'

class String
  def clean
    # removes leading and trailing whitespace, commas
    self.gsub!(/(^[\s,]+)|([\s,]+$)/, '')
    return self
  end
end

module Rubyscholar
  class Paper < Struct.new(:scholar, :crossref)
  end

  class Parser
    attr_accessor :parsedPapers, :crossRefEmail

    def initialize(url, crossRefEmail = "")
      @parsedPapers  = []
      @crossRefEmail = crossRefEmail # if nil doesn't return any crossRef Info (or DOI)
      parse(url)
    end

    def parse(url)
      STDERR << "Will check #{url}.\n"
      page_content = open(url,
                          'User-Agent' => 'Mozilla/5.0 (Windows NT 6.1) AppleWebKit/535.2 (KHTML, like Gecko) Chrome/15.0.874.121 Safari/535.2')
      page = Nokogiri::HTML(page_content, nil, 'utf-8')
      papers = page.css(".gsc_a_tr")
      STDERR << "Found #{papers.length} papers.\n"
      papers.each do |paper|
        scholar = {}
        scholar[:title] = paper.css(".gsc_a_at").text rescue ''
        scholar[:title].gsub!(/\.$/, '')

        scholar[:googleUrl] = paper.children[0].children[0].attribute('href').text rescue ''
        scholar[:authors]   = paper.children[0].children[1].text.clean rescue ''
        scholar[:authors].gsub!("...", "et al")

        scholar[:journal]        = paper.children[0].children[2].text rescue ''
        scholar[:journalName]    = scholar[:journal].split(/,|\d/).first.clean  rescue ''
        scholar[:journalDetails] = scholar[:journal].gsub(scholar[:journalName], '').clean
        scholar[:year]           = scholar[:journalDetails].match(/, \d+$/)[0]  rescue ''
        scholar[:journalDetails] = scholar[:journalDetails].gsub(scholar[:year], '').clean
        scholar[:year]           = scholar[:year].clean

        #citations
        citeInfo                = paper.css('.gsc_a_ac')
        scholar[:citationCount] = citeInfo.text
        scholar[:citationUrl]   = scholar[:citationCount].empty?  ? nil : citeInfo.attribute('href').to_s

        # get CrossRef Info: needs last name of first author, no funny chars
        crossref = get_crossref(scholar[:authors], scholar[:title], @crossRefEmail)

        @parsedPapers.push(Paper.new(scholar, crossref))
      end
      STDERR << "Scraped #{parsedPapers.length} from Google Scholar.\n"
    end

    # Also get (more detailed) info from crossref (its free)
    # Set your CrossRefEmail int the config
    def get_crossref(authors, title, crossRefEmail)
      return '' if @crossRefEmail.nil?
      lastNameFirstAuthor = ((authors.split(',').first ).split(' ').last )
                              .parameterize.gsub(/[^A-Za-z\-]/, '')
      sleep(1) # to reduce risk
      STDERR << "Getting DOI for paper by #{lastNameFirstAuthor}: #{title}.\n"
      url = 'http://www.crossref.org/openurl?redirect=false' +
        '&pid='    + crossRefEmail +
        '&aulast=' + lastNameFirstAuthor +
        '&atitle=' + URI.escape(title) +
        '&format=json'
      JSON.load(open(url)) rescue ''
    end
  end

  class Formatter
    attr_accessor :parser, :nameToHighlight, :pdfLinks, :altmetricDOIs

    def initialize(parser, nameToHighlight = nil, pdfLinks = {}, altmetricDOIs = [], minCitationCount = 1)
      @parser          = parser
      @nameToHighlight = nameToHighlight
      @pdfLinks        = pdfLinks
      @altmetricDOIs   = altmetricDOIs
      @minCitations    = minCitationCount
    end

    def to_json
      papers = {}
      @parser.parsedPapers.each_with_index do |paper, idx|
        index = @parser.parsedPapers.length - idx
        papers[index] = paper.to_h
      end
      papers.to_json
    end

    def to_html
      builder = Nokogiri::HTML::Builder.new do |doc|
        doc.div(class: "publication") do
          doc.ol do
            @parser.parsedPapers.each_with_index do |paperData, index|
              paper = paperData[:scholar]
              doi   = paperData[:crossref]['created']['DOI'] rescue ''
              doc.li(value: (@parser.parsedPapers.length - index).to_s) do
                doc.b paper[:title]
                doc.text ' (' + paper[:year] + ') '
                if paper[:authors].include?(@nameToHighlight)
                  doc.text( paper[:authors].sub(Regexp.new(@nameToHighlight + '.*'), '') )
                  doc.span(class: "label") { doc.text @nameToHighlight }
                  doc.text( paper[:authors].sub(Regexp.new('.*' + @nameToHighlight), '') )
                else
                  doc.text(paper[:authors])
                end
                doc.text '. '
                doc.em   paper[:journalName] + ' '
                doc.text paper[:journalDetails]
                unless doi.empty?
                  doc.text(' ')
                  doc.a(href: URI.join("http://dx.doi.org/", doi)) do
                    doc.text "[DOI]"
                  end
                end
                if @pdfLinks.keys.include?(paper[:title])
                  doc.text(' ')
                  doc.a(href: @pdfLinks[paper[:title]]) { doc.text "[PDF]" }
                end
                if paper[:citationCount].to_i > @minCitations
                  doc.text(' ')
                  doc.a(href: paper[:citingPapers], title: "Citations") do
                    doc.span(class: "badge badge-inverse") do
                      doc.test("#{paper[:citationCount]}x")
                    end
                  end
                end
                if altmetricDOIs.include?( doi)
                  doc.text(' ')
                  doc.span(class: 'altmetric-embed',
                          'data-badge-popover':'bottom',
                          'data-doi': doi)
                end
              end
            end
          end
        end
      end
      return builder.to_html
    end
  end
end
