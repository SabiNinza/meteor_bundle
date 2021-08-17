#!/usr/bin/ruby
# encoding: UTF-8

#
# BigBlueButton open source conferencing system - http://www.bigbluebutton.org/
#
# Copyright (c) 2012 BigBlueButton Inc. and by respective authors (see below).
#
# This program is free software; you can redistribute it and/or modify it under
# the terms of the GNU Lesser General Public License as published by the Free
# Software Foundation; either version 3.0 of the License, or (at your option)
# any later version.
#
# BigBlueButton is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. See the GNU Lesser General Public License for more
# details.
#
# You should have received a copy of the GNU Lesser General Public License along
# with BigBlueButton; if not, see <http://www.gnu.org/licenses/>.
#

require "trollop"
require File.expand_path('../../../lib/recordandplayback', __FILE__)

opts = Trollop::options do
  opt :meeting_id, "Meeting id to archive", :type => String
end
meeting_id = opts[:meeting_id]

logger = Logger.new("/var/log/bigbluebutton/post_publish.log", 'weekly' )
logger.level = Logger::INFO
BigBlueButton.logger = logger

published_files = "/var/bigbluebutton/published/presentation/#{meeting_id}"
meeting_metadata = BigBlueButton::Events.get_meeting_metadata("/var/bigbluebutton/recording/raw/#{meeting_id}/events.xml")

#
### Main Code
#

require 'shellwords'
input_dir = Shellwords.escape(published_files)
output_file = Shellwords.escape("#{published_files}/video.mp4")
base_dir = '/opt/bbb-video-download'
bbb_uid = '998'
bbb_gid = '998'

BigBlueButton.logger.info("Create downloadable video for [#{meeting_id}] start")
rs = `cd #{base_dir} && docker-compose run --rm --user #{bbb_uid}:#{bbb_gid} app node index.js -i #{input_dir} -o #{output_file}`
BigBlueButton.logger.info(rs)
BigBlueButton.logger.info("Create downloadable video for [#{meeting_id}] end")


#
### Create Chunks
#


require 'net/http'
require 'json'

INTERVAL = 15
baseURL = "https://dapi.videowiki.pt"
API_URL = URI("#{baseURL}/api/create_chunks/")
VIDEO_URL = "https://class.videowiki.pt/presentation/#{meeting_id}/video.mp4"
req = Net::HTTP::Post.new(API_URL, 'Content-Type' => 'application/json')
req.body = {
    video_url: VIDEO_URL,
    option: "long",
    task_id: ''

}.to_json

BigBlueButton.logger.info(req.body)

res = Net::HTTP.start(API_URL.hostname, API_URL.port, :use_ssl => API_URL.scheme == 'https') do |http|
    http.request(req)
  end
response = JSON.parse(res.body)



task_id = response['task_id']
req.body = {
    video_url: VIDEO_URL,
    option: "long",
    task_id: task_id

}.to_json

BigBlueButton.logger.info(req.body)

status = false

until status do
    sleep INTERVAL
    response = Net::HTTP.start(API_URL.hostname, API_URL.port, :use_ssl => API_URL.scheme == 'https') do |http|
        http.request(req)
      end
    json_res = JSON.parse(response.body)
    BigBlueButton.logger.info(json_res)
    status = json_res['status']
end


exit 0
