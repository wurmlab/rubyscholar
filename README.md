# Synopsis

Here is a small script to "scrape" your Google Scholar citations and reformat them (the way I need it for my website). 
Not super flexible - but should be easily customizable.

Some features: 

 * if registered on Crossref, retreives corresponding DOIs and can add altmetric.org links. 
   If Crossref doesn't think your email is valid, no DOIs will be retreived. 
 * adds "Cited by N" for popular papers

# How to use:

1. Configure "config.yml"
   If you want DOI retreival to work (including Altmetrics), you need to be 
   registered at crossref (its free). 
2. Run `ruby bin/scrape.rb > mypublications.html`
3. Thats it. 


# Potential for improvement:

 * uses author list as visible on your main Google Scholar page. Sometimes this 
   means names are chopped in two or just a single author is missing. This could
   be made smarter. 
 * flexible output
 * flexible use of DOIs

# Technologies

Ruby, Nokogiri. Thanks to Google Scholar and Crossref. I hope none of this infringes on anything. 

# Contact

RubyScholar was developed by Yannick Wurm (http://yannick.poulet.org). Pull requests, patches and bug reports are welcome. The source code is available on github. Bug reports and feature requests may also be made there.

# Copyright

RubyScholar © 2013 by Yannick Wurm. Licensed under the MIT license. 

