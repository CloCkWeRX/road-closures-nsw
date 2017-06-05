# This is a template for a Ruby scraper on morph.io (https://morph.io)
# including some code snippets below that you should find helpful

require 'scraperwiki'
# require 'mechanize'
#
# agent = Mechanize.new
#
# # Read in a page
# page = agent.get("http://foo.com")
#
# # Find somehing on the page using css selectors
# p page.at('div.content')
#
# # Write out to the sqlite database using scraperwiki library
# ScraperWiki.save_sqlite(["name"], {"name" => "susan", "occupation" => "software developer"})
#
# # An arbitrary query against the database
# ScraperWiki.select("* from data where 'name'='peter'")

# You don't have to do things with the Mechanize or ScraperWiki libraries.
# You can use whatever gems you want: https://morph.io/documentation/ruby
# All that matters is that your final data is written to an SQLite database
# called "data.sqlite" in the current working directory which has at least a table
# called "data".

require 'open-uri' 
require 'json'


# NSW Traffic
# https://www.livetraffic.com/traffic/hazards/roadwork.json?1496658338900

if ENV['RAILS_ENV'] == 'test'
  require 'pry'

  file = IO.read('./roadwork.json')
else
  url = "https://www.livetraffic.com/traffic/hazards/roadwork.json?#{DateTime.now.strftime('%s')}"
  file = open(url).read
end

def translate_to_opencouncildata(feature)
  raise feature["properties"].inspect
  start_date, start_time = DateTime.strptime(feature["properties"]["start"], '%s').iso8601.split("T") if feature["properties"]["start"]
  end_date, end_time = DateTime.strptime(feature["properties"]["end"], '%s').iso8601.split("T") if feature["properties"]["end"]


  # "webLinks"=>[], 
  # "headline"=>"SCHEDULED ROAD WORKS - WOOLLOOMOOLOO Cross City Tunnel exit ramp to Eastern Distributor",
  # "periods"=>[{"closureType"=>"ROAD_CLOSURE", "direction"=>"Southbound", "finishTime"=>"3am", "fromDay"=>"Monday", "startTime"=>"11:30pm", "toDay"=>" "}], 
  # "speedLimit"=>-1, 
  # "webLinkUrl"=>nil,
  # "expectedDelay"=>" ",
  # "ended"=>false,
  # "isNewIncident"=>true,
  # "publicTransport"=>" ", 
  # "impactingNetwork"=>false, 
  # "subCategoryB"=>" ", 
  # "arrangementAttachments"=>[], 
  # "isInitialReport"=>false, 
  # "created"=>1496048396446, 
  # "isMajor"=>false, 
  # "name"=>nil, 
  # "subCategoryA"=>"", 
  # "adviceB"=>" ", 
  # "adviceA"=>"Exercise caution", 
  # "end"=>1496152799059, 
  # "incidentKind"=>"Planned", 
  # "mainCategory"=>"Scheduled road works", 
  # "lastUpdated"=>1496048396446, 
  # "otherAdvice"=>" ", 
  # "arrangementElements"=>[], 
  # "diversions"=>" ", 
  # "additionalInfo"=>[" "],
  # "webLinkName"=>nil, 
  # "attendingGroups"=>[" "], 
  # "duration"=>" ",
  # "start"=>1495980000000,
  # "displayName"=>"SCHEDULED ROAD WORKS",
  # "media"=>[],
  # "roads"=>[{"conditionTendency"=>"", "crossStreet"=>"Eastern Distributor", "delay"=>"", "impactedLanes"=>[], "locationQualifier"=>"to", "mainStreet"=>"Cross City Tunnel exit ramp", "quadrant"=>"", "queueLength"=>0, "region"=>"SYD_MET", "secondLocation"=>" ", "suburb"=>"Woolloomooloo", "trafficVolume"=>""}]

  # Infer the status
  status = "open" if feature["properties"]["ended"]
  status ||= feature["properties"]["speedLimit"] < 0 ? "closed" : "restricted"

  feature["properties"] = {
    "status" => status,
    "start_date" => start_date,
    "start_time" => start_time,

    "end_date" => end_date,
    "end_time" => end_time,
    # "ref"=> feature["properties"]["ID"],
    # "updated" => feature["properties"]["UPDATEDATE"],
    "reason_desc" => feature["properties"]["headline"],
    "source" => "livetraffic.com",
  }

  # TODO Assess if minutes?
  feature["properties"]["delay_mins"] = features["properties"]["expectedDelay"] if features["properties"]["expectedDelay"] != " "

  #   status  The level of impact: closed (no movement), restricted (speed restrictions and possible lane closures), open (open, included if necessary to avoid doubt), detour (this line feature is a recommended detour around another closure)
  # start_date  Date of start of closure, in ISO8601 format: 2015-06-04
  # start_time  Time of start of closure, in ISO8601 local timezone format: 08:30+10 (preferred) or no timezone format: 08:30. For an unplanned closure without an exact known start date, use any time in the past. Do not use UTC format

  # end_date,end_time As for start_date, start_time for the anticipated end of the closure, if known.
  # reason  One of: Works (including road works, building construction, water mains), Event, Unplanned (e.g. emergency maintenance), Crash, Natural (fire, flood, weather)
  # reason_desc Free text description of the reason for the closure or restriction.
  # status_desc Free text description of the extent of the closure or restriction.
  # direction Direction in which traffic is affected. One of Both, Inbound,Outbound,North,South,West,East, etc.
  # updated The most recent date and time at which this information was known to be current, in combined ISO8601 format (eg, 2015-06-04T08:15+10)

  # source  The source of the closure, eg Victoria Police, Western Energy
  # delay_mins  The number of minutes delay anticipated for motorists proceeding through an affected area. Can be either a single number 15 or a range 5-10.
  # impact  The level of impact this is expected to have on traffic flows in the area, from 1 (minimal) to 5 (severe). This is intended to aid in filtering data for mapping.
  # ref A council-specific identifier.
  # event_id  A council-specific identifier for an associated event, if any.
  # url A website link for more information.
  # phone A phone number to call for more information.
  # daily_start, daily_end  For works across multiple days, the time at which closure begins and ends each day, in ISO8601 local timezone (preferred) or no timezone format.

  feature
end

data = JSON.parse(file)
features = data["features"]
features.each do |feature|
  record = translate_to_opencouncildata(feature.dup)["properties"]

  # Assume its a Point
  record["longitude"], record["latitude"] = feature["geometry"]["coordinates"]

  ScraperWiki.save_sqlite(["start_date", "start_time", "latitude", "longitude"], record)
end
