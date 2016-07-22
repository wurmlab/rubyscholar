require 'nokogiri'
require 'open-uri'
require 'rubyscholar-version'
require 'json'

class String
  def clean
    # removes leading and trailing whitespace, commas
    self.gsub!(/(^[\s,]+)|([\s,]+$)/, '')
    return self
  end
end

module Rubyscholar
  class Paper < Struct.new(:title, :url, :authors, :journalName, :journalDetails, :year, :citationCount, :citingPapers, :doi)
  end  
  
  class Parser
    attr_accessor :parsedPapers, :crossRefEmail
    
    def initialize(url, crossRefEmail = "")
      @parsedPapers  = []
      @crossRefEmail = crossRefEmail # if nil doesn't return any DOI
      parse(url)
    end

    def parse(url)
      STDERR << "Will check #{url}.\n"
      page = Nokogiri::HTML(open(url,
                                 'User-Agent' => 'Mozilla/5.0 (Windows NT 6.1) AppleWebKit/535.2 (KHTML, like Gecko) Chrome/15.0.874.121 Safari/535.2'), nil, 'utf-8')
      papers = page.css(".gsc_a_tr")
      STDERR << "Found #{papers.length} papers.\n"
      papers.each do |paper|
        title          = paper.css(".gsc_a_at").text rescue ''
        title.gsub!(/\.$/, '')

        googleUrl      = paper.children[0].children[0].attribute('href').text rescue ''
        authors        = paper.children[0].children[1].text.clean rescue ''
        authors.gsub!("...", "et al")

        journal        = paper.children[0].children[2].text rescue '' 
        journalName    = journal.split(/,|\d/).first.clean  rescue ''
        journalDetails = journal.gsub(journalName, '').clean 
        year           = journalDetails.match(/, \d+$/)[0]  rescue ''
        journalDetails = journalDetails.gsub(year, '').clean
        year           = year.clean

        #citations
        citeInfo      = paper.css('.gsc_a_ac')
        citationCount = citeInfo.text
        citationUrl   = citationCount.empty?  ? nil : citeInfo.attribute('href').to_s 

        # get DOI: needs last name of first author, no funny chars
        lastNameFirstAuthor = ((authors.split(',').first ).split(' ').last ).gsub(/[^A-Za-z\-]/, '')
        doi                 = getDoi( lastNameFirstAuthor, title, @crossRefEmail)

        @parsedPapers.push(Paper.new( title, googleUrl, authors, journalName, journalDetails, year, citationCount, citationUrl, doi))
      end
      STDERR << "Scraped #{parsedPapers.length} from Google Scholar.\n"
    end

    # Scholar doesn't provide DOI. 
    # But if registered at crossref (its free), DOI can be retreived. 
    def getDoi(lastNameFirstAuthor, title, crossRefEmail)
      return '' if @crossRefEmail.nil?
      sleep(1) # to reduce risk 
      STDERR << "Getting DOI for paper by #{lastNameFirstAuthor}: #{title}.\n"
      url = 'http://www.crossref.org/openurl?redirect=false' +  
        '&pid='    + crossRefEmail + 
        '&aulast=' + lastNameFirstAuthor   +
        '&atitle=' + URI.escape(title)
      crossRefXML = Nokogiri::XML(open(url)) 
      crossRefXML.search("doi").children.first.content rescue ''
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
        doc.div( :class => "publication") {
          doc.ol {	
            @parser.parsedPapers.each_with_index do |paper, index|
              doc.li( :value=> ( (@parser.parsedPapers).length - index).to_s)  {
                doc.b paper[:title]
                doc.text ' (' + paper[:year] + ') '
                if paper[:authors].include?(@nameToHighlight)
                  doc.text( paper[:authors].sub(Regexp.new(@nameToHighlight + '.*'), '') )
                  doc.span( :class => "label") { doc.text @nameToHighlight }
                  doc.text( paper[:authors].sub(Regexp.new('.*' + @nameToHighlight), '') )
                else
                  doc.text( paper[:authors])
                end
                doc.text '. '
                doc.em   paper[:journalName] + ' '
                doc.text paper[:journalDetails]
                unless paper[ :doi].empty?
                  doc.text(' ')
                  doc.a( :href => URI.join("http://dx.doi.org/", paper[ :doi]))  { 
                    doc.text "[DOI]" 
                  } 
                end
                if @pdfLinks.keys.include?(paper[:title])
                  doc.text(' ')
                  doc.a( :href => @pdfLinks[paper[:title]])  { 
                    doc.text "[PDF]"
                  } 
                end
                if paper[ :citationCount].to_i > @minCitations
                  doc.text(' ')
                  doc.a( :href => paper[ :citingPapers], :title => "Citations") { 
                    doc.span( :class => "badge badge-inverse") { doc.test("#{paper[ :citationCount]}x") }
                  } 
                end
                if altmetricDOIs.include?( paper[ :doi])
                  doc.text(' ')
                  doc.span( :class                => 'altmetric-embed',
                            :'data-badge-popover' => 'bottom',
                            :'data-doi'           => paper[ :doi]        )
                end
              }
            end
          }
        }
      end
      return builder.to_html
    end
  end
end
