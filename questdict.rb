require 'sinatra'
require 'haml'
require 'open-uri'
#require File.dirname(__FILE__) + 'lib/all'
require_relative './lib/quest_dict_backend.rb'

questdict = QuestDict.new("english")
# configure :developement do
#   set :questdict, QuestDict.new("dictionary","words1")
# end

helpers do
  include Rack::Utils
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
      @meanings = questdict.find_meanings(@word)
      if(@meanings.empty?)
        @suggestions = questdict.get_suggestions(@word)
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
  unless questdict.parse_html_and_update_dictionary(wordsdoc)
    return haml :uploadfailed, :layout => false
  end
  haml :uploadsuccess, :layout => false
end

post '/load' do
  if(params["link"].empty?)
    redirect '/uploaddict'
  end 
  wordsdoc = Hpricot(open(params["link"].strip))
  unless questdict.parse_html_and_update_dictionary(wordsdoc)
    return haml :uploadfailed, :layout => false
  end
  haml :uploadsuccess, :layout => false
end


get '/credits' do
  haml :credits
end
