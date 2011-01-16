require 'sinatra'
require 'haml'
require 'mongo'
require 'hpricot'
require 'open-uri'

module QuestDict

  def self.db
    @@db ||= connect
  end

  def self.connect
    Mongo::Connection.new.db("dictionary").collection("words1")
  end

  ############################################################################################################
  # Following function parses Hpricot HTML document.                                                         #
  # I used Online Plain Text English Dictionary (http://www.mso.anu.edu.au/~ralph/OPTED/) to write this app. #
  # This specifies following structure for a word entry:                                                     #
  #     Word       - will be enclosed in <b> </b> HTML tag                                                   #
  #     Category   - part of speech or type will be enclosed in (<i> </i>)                                   #
  #     Meaning    - It follows character ')' after category                                                 #
  #     And this whole entry will be enclosed in <p></p> HTML tag                                            #
  #                                                                                                          #
  # Also it is mentioned that original text is written in "Western                                           #
  # MacRoman" encoding.                                                                                      #
  ############################################################################################################

  def self.parse_html_and_update_dictionary (html_wordsdoc)
    # Whole word entry is wrapped under <p> </p> tag
    html_words = (html_wordsdoc/"p")
    if html_words.empty?
      @error = "could not find word entries in given document"  # Insert a timestamp as well
      return false
    end

    count = 0   # Counter to count number of words pushed into database 
    html_words.each do |html_wordentry|
      db_wordentry = { }
      # Actual word is wrapped under <b> </b> tag
      word = (html_wordentry/"b").inner_html

      str = html_wordentry.inner_html
      
      # If the encoding selected by Ruby itself is wrong then force
      # "macroman" encoding and re-encode in "UTF-8" for split
      # function on the word entry.
      unless str.valid_encoding?
        str.force_encoding("macRoman") 
        str.encode("UTF-8")
      end

      # Meaning follows character ")"  
      meaning= str.split(")")

      unless word.empty?
        if meaning.count >= 2
          db_wordentry.merge!("word" => word.strip.split(" ")[0].downcase)
          # Categories of word is wrapped under <i> </i>
          db_wordentry.merge!("category" => (html_wordentry/"i").inner_html)
          db_wordentry.merge!("meaning" => meaning[1].strip)
          self.db.insert(db_wordentry)
          count = count.succ
        end
      end
    end
    unless count > 0
      @error = "No word entry added in database. Hence invalid html file" # Add timestamp also
      return false
    end
    return true
  end

end

get '/' do
  haml :dictionary
end

get '/search' do
  @word = ""
  @meanings = []
  unless params.empty?
    unless params[:word].strip.empty?
      # Strip the word string, Get only one word (multiple word searching
      # not supported) and downcase it for searching.
      @word = params[:word].strip.split(" ")[0].downcase
      
      QuestDict.db.find( "word" => @word).each do |word|     # Populate meanings into an array
        @meanings << { :meaning => word["meaning"], :category => word["category"] }
      end
    end
  end
  haml :dictword
end

get '/uploaddict' do
  haml :uploaddict
end

post '/uploaddict' do
  # Obtain the uploaded file
  unless params[:file] &&
      (wordsfile = params[:file][:tempfile]) &&
      (name = params[:file][:filename])
    @error = "No File selected"
    return haml :uploaddict
  end

  # convert the opened file into Hpricot document
  wordsdoc = Hpricot(wordsfile)
  unless QuestDict.parse_html_and_update_dictionary(wordsdoc)
    return haml :uploadfailed, :layout => false
  end
  haml :uploadsuccess, :layout => false
end

post '/load' do
  wordsdoc = Hpricot(open(params["link"].strip))
  unless QuestDict.parse_html_and_update_dictionary(wordsdoc)
    return haml :uploadfailed, :layout => false
  end
  haml :uploadsuccess, :layout => false
end
