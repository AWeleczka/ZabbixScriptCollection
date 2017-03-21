#!/usr/bin/env ruby
# frozen_string_literal: true

require 'uri'
require 'net/http'
require 'yaml'

currentdir = File.dirname(__FILE__)
unless File.file?(currentdir + '/../config.yml')
  puts 'E: You have to create the "config.yml" file in the root directory of '\
       'this repository first.'
  if File.file?(currentdir + '/../config.yml.tmp')
    puts 'I: You can get started by copying the "config.yml.tmp" file from'\
         'the root directory'
  else
    puts 'I: Check the original repository at '\
         '"https://github.com/AWeleczka/ZabbixScriptCollection" for a template'
  end
  exit 1
end

config = YAML.load_file(currentdir + '/../config.yml')

usertoken, payload = ARGV
unless usertoken.nil? || payload.nil?
  puts 'E: Usage: ./zabbixPushover.rb <pushover_user_token> <zabbix_payload>'
  exit 1
end

zabbixdata = {}
payload.split("\n").each do |load|
  tmp = load.split('=')
  zabbixdata[tmp[0].strip] = tmp[1].strip
end

unless zabbixdata['TRIGGER.STATUS'].nil? || zabbixdata['TRIGGER.SEVERITY'].nil?
  puts 'E: Payload is missing required data'
  exit 1
end

subject  = ''
message  = ''
priority = '0'
retrie   = ''
expire   = ''
eventurl = [
  config['zabbix']['host'],
  '/tr_events.php?triggerid=',
  read_from_hash(zabbixdata, 'TRIGGER.ID'),
  '&eventid=',
  read_from_hash(zabbixdata, 'EVENT.ID')
].join

if zabbixdata['TRIGGER.STATUS'] == 'OK'
  subject = [
    read_from_hash(zabbixdata, 'HOST.NAME1'),
    ' recovered'
  ].join
  message = [
    read_from_hash(zabbixdata, 'ITEM.NAME1'),
    ' = ',
    read_from_hash(zabbixdata, 'ITEM.VALUE1')
  ].join
  priority = case zabbixdata['TRIGGER.SEVERITY']
             when 'Information', 'Warning'
               '-2'
             else
               '-1'
             end
else
  subject = [
    read_from_hash(zabbixdata, 'TRIGGER.SEVERITY'),
    ' : ',
    read_from_hash(zabbixdata, 'HOST.NAME1'),
    ' ',
    read_from_hash(zabbixdata, 'TRIGGER.NAME')
  ].join
  message = [
    read_from_hash(zabbixdata, 'ITEM.NAME1'),
    ' = ',
    read_from_hash(zabbixdata, 'ITEM.VALUE1')
  ].join
  priority = case zabbixdata['TRIGGER.SEVERITY']
             when 'Information'
               '-2'
             when 'Warning'
               '-1'
             when 'Average'
               '0'
             when 'High'
               '1'
             when 'Disaster'
               '2'
             end
  if zabbixdata['TRIGGER.SEVERITY'] == 'Disaster'
    retrie = '60'
    expire = '900'
  end
end

uri = URI(config['pushover']['endpoint'])
req = Net::HTTP::Post.new(uri.path)
req.set_form_data(
  'token' => config['pushover']['apptoken'],
  'user' => usertoken,
  'html' => 1,
  'title' => subject,
  'message' => message,
  'url' => eventurl,
  'url_title' => 'Open in Zabbix',
  'priority' => priority,
  'retry' => retrie,
  'expire' => expire
)

puts 'I: ' + Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
  http.request(req)
end
exit 0

def read_from_hash(hash, key)
  if hash[key].nil?
    '{' + key + '}'
  else
    hash[key]
  end
end
