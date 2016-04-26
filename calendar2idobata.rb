# -*- coding: utf-8 -*-
require 'google/apis/calendar_v3'
require 'googleauth'
require 'googleauth/stores/file_token_store'

require 'fileutils'
require 'idobata'
require 'pry'
require 'multi_json'

OOB_URI          = 'urn:ietf:wg:oauth:2.0:oob'
APPLICATION_NAME = 'Ruby Quickstart'
SECRETS_PATH = File.join("./", 'tmp', "calendar-secrets.yaml")
TOKENS_PATH  = File.join("./", 'tmp', "calendar-tokens.yaml")

SCOPE = Google::Apis::CalendarV3::AUTH_CALENDAR_READONLY

# TODO: Not using a tempfile may be better implementation
module Google
  module Auth
    module Stores
      # Implementation of user token storage backed by a local YAML file
      #class FileTokenStore < Google::Auth::TokenStore
      class FileTokenStore
        # @param [String, File] file
        #  Path to storage file
        #def initialize(options = {})
        #  path = options[:file]
        #  @store = YAML::Store.new(path)
        #end

        def initialize(options = {})
          path = options[:file]
          #puts path
          @store = YAML::Store.new(path)
          # @store = YAML::Load(ENV[""])
        end
        # Create a new store with the supplied file.
      end
    end
  end
end


def authorize
  FileUtils.mkdir_p(File.dirname(SECRETS_PATH))

  #client_id   = Google::Auth::ClientId.from_file(CLIENT_SECRETS_PATH)
  client_id   = Google::Auth::ClientId.from_hash(MultiJson.load(ENV["GOOGLE_SECRETS"]))

  #token_store = Google::Auth::Stores::FileTokenStore.new(file: SECRETS_PATH)
  File.open(TOKENS_PATH, "w") do |f|
    y = ENV["GOOGLE_TOKENS"].gsub("%", "\'")
    puts y
    f.write y
  end
  token_store = Google::Auth::Stores::FileTokenStore.new(file: TOKENS_PATH)
  authorizer  = Google::Auth::UserAuthorizer.new(client_id, SCOPE, token_store)

  user_id = 'default'
  credentials = authorizer.get_credentials(user_id)
  if credentials.nil?
    url = authorizer.get_authorization_url(base_url: OOB_URI)
    puts 'Open the following URL in the browser and enter the ' +
         'resulting code after authorization'
    puts url
    code = gets
    credentials = authorizer.get_and_store_credentials_from_code(
      user_id: user_id, code: code, base_url: OOB_URI)
  end

  File.delete TOKENS_PATH
  credentials
end

# Initialize the API
service = Google::Apis::CalendarV3::CalendarService.new
service.client_options.application_name = APPLICATION_NAME
service.authorization = authorize

# Fetch today's events
calendar_id = ENV['CALENDAR_ID']
today    = Date.today.strftime('%Y-%m-%dT00:00:00+09:00')
tomorrow = (Date.today + 1).strftime('%Y-%m-%dT00:00:00+09:00')
response = service.list_events(
                        calendar_id,
                        time_min: today,
                        time_max: tomorrow)

# Generate a message
msg =  ""
events = { }
response.items.each do |event|
  next if event.start.nil?
  start = "00:00"  if event.start.date
  start = start    || event.start.date_time.strftime("%H:%M")
  events[start] = event.summary
end

events.sort_by{|start,summary| start.delete(":").to_i }.to_h.each do |start,summary|
  next if summary.include? "Private"
  msg += "<span class='label label-info'>#{start}</span> - #{summary}<br />"
end
msg.gsub!("00:00", "&nbsp;メモ&nbsp;")
puts msg

# Send a message to Idobata
#Idobata.hook_url = ENV['IDOBATA_SANDBOX']
Idobata.hook_url = ENV['IDOBATA_LOUNGE']
Idobata::Message.create(source: msg, format: :html) unless msg.empty?

