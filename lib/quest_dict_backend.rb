# Implements QuestDict class 

require 'mongo'
require 'hpricot'


class QuestDict
  attr_reader :db
  def initialize (database,collection)
    @db = Mongo::Connection.new.db(database).collection(collection) 
  end

  # Following method finds a given word in dictionary databse
  # Input: word (string) you need to search
  # Output: Flag (Boolean; word found or not)
  #         Meaning (Array; if Flag = TRUE, this will contain
  #                                         collection as entries
  #                            Flag = false, then "Did you mean?" word
  #                                          list. currently this
  #                                          feature is not implemented)
  
  def find_meanings (word)
    word = word.strip
    meanings = []
    unless word.empty?

      @db.find( "word" => word.downcase).each do |word_entry|     # Populate meanings into an array
        meanings << { :meaning => word_entry["meaning"], :category => word_entry["category"] }
      end
    end

    unless meanings.empty?
      return true, meanings
    end
    return false,Array.new
  end

  # Following method adds word entry into database.
  # before adding it validates whether a entry with same word &
  # meaning already exist in the database. If yes then entry not added
  # else it will be added in database.
  # Input : wordentry (Hash e.g. {"word" => "hello",
  #                               "meaning" => "An expression of greeting",
  #                               "category" => "v. p.p."})
  # Output: A Boolean specifying operation was successful or not.
  def add_word (word_entry)
    if word_entry.class.to_s == "Hash"
      if word_entry.has_key?("word") && word_entry.has_key?("meaning")
       
        unless word_entry["word"].strip.empty? || word_entry["meaning"].strip.empty?
       
          word_entry["word"] = word_entry["word"].strip.downcase
          word_entry["meaning"] = word_entry["meaning"].strip
          
          # Search whether database has Meaning entries for this word
          flag, meanings = find_meanings(word_entry["word"])
         
          unless flag  # New word, add word_entry
            @db.insert(word_entry)  # catch Databse insertion exceptions
            return true
          end

          # If meanings found for word, check whether new meaning
          # already exists or not.
          meaning_found = false
          meanings.each do |meaning_entry|
            meaning_found = true if meaning_entry.has_value?(word_entry["meaning"])
          end
          unless meaning_found # new meaning, add word_entry
            @db.insert(word_entry) #catch Database insertion exceptions
            return true
          end
        end
      end
    end
    return false
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

  def parse_html_and_update_dictionary (html_wordsdoc)
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
          count = count.succ if add_word(db_wordentry)
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

