# Implements QuestDict class 

require 'uri'
require 'mongo'
require 'hpricot'


class QuestDict
  attr_reader :db
  def initialize (collection)
    # following three lines are directly copied from Mongohq docs page
    # on Heroku
    uri = URI.parse(ENV['MONGOHQ_URL'])
    conn = Mongo::Connection.from_uri(ENV['MONGOHQ_URL'])
    db = conn.db(uri.path.gsub(/^\//, ''))
    
    @db = db.collection(collection)
    @wordsdb = db.collection(collection + '_words')
  end

  # Following method finds a given word in dictionary databse
  # Input: word (string) you need to search
  # Output:  Meaning (Array; if entries found then will have hashed
  #                   entries, else will be empty)
  
  def find_meanings (word)
    word = word.strip
    meanings = []
    unless word.empty?

      @db.find( "word" => word.downcase).each do |word_entry|     # Populate meanings into an array
        meanings << { :meaning => word_entry["meaning"], :category => word_entry["category"] }
      end
    end

    return meanings
  end

  # Following method adds word entry into database.
  # before adding it validates whether a entry with same word &
  # meaning already exist in the database. If yes then entry not added
  # else it will be added in database.
  # Input : wordentry (Hash e.g. {"word" => "hello",
  #                               "meaning" => "An expression of greeting",
  #                               "category" => "v. p.p."})
  # Output: A Boolean specifying operation was successful or not.
  def add_word (word_meaning_entry)
    if word_meaning_entry.class.to_s == "Hash"
      if word_meaning_entry.has_key?("word") && word_meaning_entry.has_key?("meaning")
       
        unless word_meaning_entry["word"].strip.empty? || word_meaning_entry["meaning"].strip.empty?
       
          word_meaning_entry["word"] = word_meaning_entry["word"].strip.downcase
          word_meaning_entry["meaning"] = word_meaning_entry["meaning"].strip
          
          # Search whether database has Meaning entries for this word
          meanings = self.find_meanings(word_meaning_entry["word"])
         
          if meanings.empty?  # New word, add word_meaning_entry
            @db.insert(word_meaning_entry)  # catch Databse insertion exceptions
            word_entry = {"word" => word_meaning_entry["word"]}
            @wordsdb.insert(word_entry)
            return true
          end

          # If meanings found for word, check whether new meaning
          # already exists or not.
          meaning_found = false
          meanings.each do |meaning_entry|
            meaning_found = true if meaning_entry.has_value?(word_meaning_entry["meaning"])
          end
          unless meaning_found # new meaning, add word_meaning_entry
            @db.insert(word_meaning_entry) #catch Database insertion exceptions
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
      unless word.valid_encoding?
        word.force_encoding("macRoman") 
        word.encode("UTF-8")
      end

      # Meaning follows character ")"  
      meaning= str.split(")")

      unless word.empty?
        if meaning.count >= 2
          db_wordentry.merge!("word" => word.strip.split(" ")[0].downcase)
          # Categories of word is wrapped under <i> </i>
          db_wordentry.merge!("category" => (html_wordentry/"i").inner_html)
          db_wordentry.merge!("meaning" => meaning[1].strip)
          count = count.succ if self.add_word(db_wordentry)
        end
      end
    end
    unless count > 0
      @error = "No word entry added in database. Hence invalid html file" # Add timestamp also
      return false
    end
    return true
  end

  # Following function returns all the words that start with given
  # letter.
  # Input : takes a single letter
  # Output: Words: Array which has all the words that starts with
  #                given letter
  
  def words_sw_letter(letter)
    words = []
    unless letter.empty?
      @wordsdb.find({"word" => /^#{letter[0]}/}).each { |word_entry| words << word_entry["word"]}
    end
    return words
  end

  #Following function modifies a word-meaning entry
  # Input : wordentry (Hash e.g. {"word" => "hello",
  #                               "old_meaning" => "An expression of greeting",
  #                               "new_meaning" => "Way to start conversation",
  #                               "category" => "v. p.p."})
  # Output: A Boolean specifying operation was successful or not.
  def modify_word(word_meaning_entry)
    if word_meaning_entry.class.to_s == "Hash"
      if word_meaning_entry.has_key?("word") && word_meaning_entry.has_key?("old_meaning")
        
        unless word_meaning_entry["word"].strip.empty? || word_meaning_entry["old_meaning"].strip.empty?
          #since word & meaning both constitutes primary key, we can
          #use find_one here. 
          db_entry = @db.find_one({"word" => new_entry["word"],"meaning" => new_entry["old_meaning"]})

          if db_entry.empty? #if no entry found, how can we modify it?
            #update this db_entry with values we need to modify
            word_meaning_entry.each_pair do | key, value |
              next if key == "word" || key == "old_meaning" || key == "_id"
              if key == "new_meaning" && !(value.strip.empty?)
                db_entry["meaning"] = value.strip
              else
                db_entry[key] = value.strip
              end
            end
            @db.update({"_id" => db_entry["_id"]},db_entry)
            return true
          end
          
        end
      end
    end
    return false
  end

  #Following function removes a word entry/word entries
  # Input : wordentry (Hash e.g. {"word" => "hello",
  #                               "meaning" => "An expression of greeting"}
  # Output: Always returns TRUE, until some exception is caught
  def remove_word(word_entry)
    if word_meaning_entry.class.to_s == "Hash"
      unless word_entry["word"].strip.empty?
        if word_entry.has_key?("meaning")
          unless word_entry["meaning"].strip.empty?
            #remove a particular entry from word_meaning db and check count if
            #there are 0 entries in words_db then remove the word from words
            #db
            word_entry["word"] = word_entry["word"].strip
            word_entry["meaning"] = word_entry["meaning"].strip
            @db.remove(word_entry)
            @wordsdb.remove({"word" => word_entry["word"]}) if @db.find({"word" => word_entry["word"]}).count == 0
          end
        else
          #remove word from words db and all meanings from word_meaning db
          word_entry["word"] = word_entry["word"].strip
          @db.remove(word_entry)
          @wordsdb.remove(word_entry)
        end  
      end
    end
    return True
  end


end

