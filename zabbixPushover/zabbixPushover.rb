#!/usr/bin/env ruby

require 'uri'
require 'net/http'

# Information related to Pushover-API
pushoverhost	= "https://api.pushover.net/1/messages.json"
pushovertoken	= ""

# Information related to your Zabbix-Server
zabbixhost	= "http://127.0.0.1/zabbix"

###

usertoken, payload = ARGV
unless usertoken.nil? or payload.nil?
  zabbixdata = Hash.new
  payload.split("\n").each { |load|
    tmp = load.split("=")
    zabbixdata[tmp[0].strip] = tmp[1].strip
  }
  unless zabbixdata["TRIGGER.STATUS"].nil? && zabbixdata["TRIGGER.SEVERITY"].nil?
    subject 	= ""
    message 	= ""
    priority	= ""
    retrie      = ""
    expire      = ""
    eventurl	= zabbixhost + "/tr_events.php?triggerid=" + zabbixdata["TRIGGER.ID"] + "&eventid=" + zabbixdata["EVENT.ID"]
    if zabbixdata["TRIGGER.STATUS"] == "OK"
      subject = zabbixdata["HOST.NAME1"] + " recovered"
      message = zabbixdata["ITEM.NAME1"] + " = " + zabbixdata["ITEM.VALUE1"]
      case zabbixdata["TRIGGER.SEVERITY"]
      when "Information", "Warning"
        priority = "-2"
      else
        priority = "-1"
      end
    else
      subject = zabbixdata["TRIGGER.SEVERITY"] + " : " + zabbixdata["HOST.NAME1"] + " " + zabbixdata["TRIGGER.NAME"]
      message = zabbixdata["ITEM.NAME1"] + " = " + zabbixdata["ITEM.VALUE1"]
      case zabbixdata["TRIGGER.SEVERITY"]
      when "Information"
        priority = "-2"
      when "Warning"
        priority = "-1"
      when "Average"
        priority = "0"
      when "High"
        priority = "1"
      when "Disaster"
        priority = "2"
        retrie = "60"
        expire = "900"
      end
    end

    uri = URI(pushoverhost)
    req = Net::HTTP::Post.new(uri.path)
    req.set_form_data(
      'token' => pushovertoken,
      'user' => usertoken,
      'html' => 1,
      'title' => subject,
      'message' => message,
      'url' => eventurl,
      'url_title' => "Open in Zabbix",
      'priority' => priority,
      'retry' => retrie,
      'expire' => expire
    )
    req["Content-Type"] = "application/x-www-form-urlencoded"

    res = Net::HTTP.start(uri.hostname, uri.port, :use_ssl => uri.scheme == 'https') do |http|
      http.request(req)
    end

    puts res.body
  end
else
  puts "Usage: ./zabbixPushover.rb <user_api_token> <zabbix_payload>"
end

