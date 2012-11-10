require 'thin'
require 'sinatra'
require 'json'
require 'yaml'

class JSONDB
  class << self
    def data_path; @data_path ||= File.join(settings.root, 'db.json'); end
    def data
      @data ||= JSON.parse(File.read(data_path)) rescue []
    end

    def commit!
      @json = nil
      data.sort! { |a,b| a['name'].upcase <=> b['name'].upcase }
      File::write(data_path,data.to_json)
    end

    def find_by_name(name)
      name = name.to_s.strip.downcase
      data.find {|rec| rec['name'].downcase == name }
    end

    def upsert(name, email, phone, guests)
      name = name.to_s.strip
      return nil if name.size == 0
      record = find_by_name(name) || data.push({'name' => name}).last
      record['email'] = email.to_s.downcase.strip if email
      record['phone'] = phone.to_s.strip if phone
      record['guests'] = guests.to_i if guests
      data.delete(record) if record['name'].size == 0 || guests == 'remove'
      commit!
      record
    end

    def to_json(*a)
      @json ||= {
        :count => data.reduce(0) { |count, record| count += record['guests'].to_i },
        :guests => data
      }.to_json
    end

  end
end

puts settings.root

set :public_folder, 'public'
set :static, 'true'

get '/' do
  send_file File.join(settings.public_folder, 'index.html')
end

get '/guests' do
  content_type :json
  JSONDB.to_json
end

post '/rsvp' do
  content_type :json
  @rsvp = JSON.parse(request.body.read.to_s) rescue {}
  @record = JSONDB.upsert(@rsvp['name'], @rsvp['email'], @rsvp['phone'], @rsvp['guests'])
  halt(400, {:message=>'enter a name to RSVP'}.to_json) unless @record
  JSONDB.to_json
end
