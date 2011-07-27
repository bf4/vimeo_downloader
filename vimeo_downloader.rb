require 'rubygems'
require 'httparty'
require 'yaml'
require 'set'
%w{open-uri rss/0.9 rss/1.0 rss/2.0 rss/parser}.each do |lib|
  require(lib)
end

VIDEO_FILE = "downloaded_videos.yml"

class VimeoDownloader
  attr_reader :xml_hash, :video_id, :is_hd, :feed, :links, :downloaded_videos
  
  def initialize
    @downloaded_videos = load_downloaded_videos_file
  end

  def download_video_feed(feed = nil)
    if feed
      get_feed(feed)
      get_links
     # reject_already_downloaded
      links.each do |link|
        download_video(link)
      end
    end
    write_downloaded_videos_file
  end

  def download_video(video_string = nil)
    if video_string
      @video_id = video_string.to_s.match(/(vimeo.com\/)?(\d+)$/)[-1]
      get_xml_hash
      download
      write_downloaded_videos_file unless defined?(@feed)
    else
      raise "enter a video string!"
    end
  end

  private

  def load_downloaded_videos_file
    if File.exist?(VIDEO_FILE)
      YAML.load(File.read(VIDEO_FILE)) || Set.new
    else
      Set.new
    end
  end

  def write_downloaded_videos_file
    File.open(VIDEO_FILE, "w+") do |file|
      file.write(downloaded_videos.to_yaml)
    end
  end

  # format http://vimeo.com/25255379
  def already_downloaded?
    downloaded_videos.include?(vimeo_video_url)
  end

  def add_downloaded_video
    downloaded_videos.add(vimeo_video_url)
  end

  def vimeo_video_url
     "http://vimeo.com/#{video_id}"
  end

  def download
    if video_id and not already_downloaded?
      download_link = "http://www.vimeo.com/moogaloop/play/clip:#{video_id}/#{request_signature}/#{request_signature_expires}/?q=#{is_hd}"
      print "  -- I would have downloaded this -- "
      puts download_link
      #`wget #{download_link} -O #{filename}`
      add_downloaded_video
    else
      puts "already downloaded #{vimeo_video_url}"
    end
  end

  def get_xml_hash
    @xml_hash = HTTParty.get(xml)
  end

  def xml
    "http://www.vimeo.com/moogaloop/load/clip:#{video_id}"
  end

  
  def get_feed(rss_feed)
    if rss_feed
      response = HTTParty.get(rss_feed)
      @feed = RSS::Parser.parse(response.body, false)
    end
  end
  

  def get_links
    if feed
      @links = feed.items.map {|item| item.link.gsub(/[^\d]/, '') }
    end
  end 

  def reject_already_downloaded
    files = File.read("downloaded.txt").split("\n")
    rejected = links.reject! {|link| files.include?(link)}
  end

  
  def request_signature
    xml_hash["xml"]["request_signature"]
  end

  def request_signature_expires
    xml_hash["xml"]["request_signature_expires"]
  end

  def caption
    xml_hash["xml"]["video"]["caption"].gsub(/[^a-zA-Z0-9]/,'_')
  end

  def is_hd
   @is_hd = (xml_hash["xml"]["video"]["isHD"] == "1") ? "hd" : "sd"
  end

  def file_extension
    (is_hd == "hd") ? "mp4" : "flv"
  end
  
  def filename
    "#{video_id}-#{caption}#{is_hd}.#{file_extension}"
  end

end

if ARGV[0] == "video"
  v = VimeoDownloader.new
  v.download_video(ARGV[1])
elsif ARGV[0] == "feed"
  v = VimeoDownloader.new
  v.download_video_feed(ARGV[1])
else
  puts "Format 'ruby vimeo_downloader.rb [feed | video] [feed_url | video_id ]'"
end
