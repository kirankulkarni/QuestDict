require 'sinatra'
require 'haml'
require 'mongo'
require 'hpricot'
require 'open-uri'

con = Mongo::Connection.new
db = con.db("dictionary")
coll = db.collection("words1")


get '/' do
  haml :dictionary
end

post '/' do
  @word = params["word"]
  @meanings = []
  coll.find( "word" => params["word"].downcase).each do |word|
    @meanings << { :meaning => word["meaning"], :category => word["category"] }
  end
  haml :dictword
end

get '/upload' do
  haml :uploaddict
end

post '/upload' do
  # Obtain the uploaded file
  unless params[:file] &&
      (wordsfile = params[:file][:tempfile]) &&
      (name = params[:file][:filename])
    @error = "No File selected"
    return haml :uploaddict
  end

  # convert the opened file into Hpricot document
  wordsdoc = Hpricot(wordsfile)
  
  # Whole word entry is wrapped under <p> </p> tag
  words = (wordsdoc/"p")

  if words.empty?
    @reason = "No word entries found in provided document."
    return haml :uploadfailed :layout => false
  end
  
  words.each do |html_wordentry|
    doc_word = { }
    # Actual word is wrapped under <b> </b> tag
    word.merge!("word" => (html_wordentry/"b").inner_html.downcase)
    # Categories of word is wrapped under <i> </i>
    word.merge!("category" => (html_wordentry/"i").inner_html)
    
    str = html_wordentry.inner_html
    unless str.valid_encoding?
      str.force_encoding("macRoman") 
      str.encode("UTF-8")
    end
    
    htmldata= str.split(")")
    word.merge!("meaning" => htmldata[1].strip)
    coll.insert(word)
  end

  haml :dictionary

end

post '/load' do
  wordsdoc = Hpricot(open(params["link"].strip))
  # Whole word entry is wrapped under <p> </p> tag
  (wordsdoc/"p").each do |wordentry|
    word = { }
    # Actual word is wrapped under <b> </b> tag
    word.merge!("word" => (wordentry/"b").inner_html.downcase)
    # Categories of word is wrapped under <i> </i>
    word.merge!("category" => (wordentry/"i").inner_html)
    
    str = wordentry.inner_html
    unless str.valid_encoding?
      str.force_encoding("macRoman") 
      str.encode("UTF-8")
    end
    
    htmldata= str.split(")")
    word.merge!("meaning" => htmldata[1].strip)
    puts word
    coll.insert(word)
  end
  haml :dictionary
end


