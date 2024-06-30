require 'sinatra'

get '/' do
  erb :index, layout: :'layouts/layout' #, locals: { headers: headers, data: data }
end
