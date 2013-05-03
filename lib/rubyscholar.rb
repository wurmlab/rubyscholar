require "nokogiri"
require "open-uri"

class String
  def clean
    # removes leading and trailing whitespace, commas
    self.gsub!(/(^[\s,]+)|([\s,]+$)/, '')
    return self
  end
end

class RubyScholar
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
      papers = Nokogiri::HTML(open(url)).css(".cit-table .item")
      STDOUT << "Found #{papers.length} papers.\n"
      papers.each do |paper|
        paperDetails   = paper.css("#col-title")
        title          = paperDetails[0].children[0].content.clean
        googleUrl      = paperDetails[0].children[0].attribute('href')
        authors        = paperDetails[0].children[2].content.clean
        authors.gsub!("...", "et al")

        journal        = paperDetails[0].children[4].content
        journalName    = journal.split(/,|\d/).first.clean
        journalDetails = journal.gsub(journalName, '').clean

        year           = paper.css("#col-year").text # is the last thing we get

        #citations
        citeInfo      = paper.css(".cit-dark-link")
        citationCount = citeInfo.text
        citationUrl   = citationCount.empty?  ? nil : citeInfo.attribute('href').to_s 

        # get DOI: needs last name of first author, no funny chars
        lastNameFirstAuthor = ((authors.split(',').first ).split(' ').last ).gsub(/[^A-Za-z\-]/, '')
        doi                 = getDoi( lastNameFirstAuthor, title, @crossRefEmail)

        @parsedPapers.push(Paper.new( title, googleUrl, authors, journalName, journalDetails, year, citationCount, citationUrl, doi))
      end
      STDOUT << "Scraped #{parsedPapers.length} from Google Scholar.\n"
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

    def to_html
      ##@doc = Nokogiri::HTML::DocumentFragment.parse "" 
      builder = Nokogiri::HTML::Builder.new do |doc|
        doc.html {
          doc.body {
            @parser.parsedPapers.each_with_index { |paper, index|
              doc.div( :class => "publication") {
                doc.p {
                  doc.text ((@parser.parsedPapers).length - index).to_s + '. ' 

                  if paper[:authors].include?(@nameToHighlight)
                    doc.text( paper[:authors].sub(Regexp.new(@nameToHighlight + '.*'), '') )
                    doc.span( :class => "me") { doc.text @nameToHighlight }
                    doc.text( paper[:authors].sub(Regexp.new('.*' + @nameToHighlight), '') )
                  else
                    doc.text( paper[:authors])
                  end
                                    
                  doc.text ' ' + paper[:year] + '. '
                  doc.b    paper[:title] + '.'
                  doc.br
                  doc.em   paper[:journalName]
                  doc.text ' '
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
                    doc.a( :href => paper[ :citingPapers]) { 
                      doc.text("[Cited #{paper[ :citationCount]}x]") 
                    } 
                  end
                  if altmetricDOIs.include?( paper[ :doi])
                    doc.text(' ')
                    doc.span( :class                => 'altmetric-embed',
                              :'data-badge-popover' => 'bottom',
                              :'data-doi'           => paper[ :doi]        )
                  end
                }
              }
            }
          }
        }
      end
      return builder.to_html
    end
  end
end


