require 'rubygems'
require 'httparty'
require 'ostruct'
require 'yaml'
require 'set'
%w{open-uri rss/0.9 rss/1.0 rss/2.0 rss/parser}.each do |lib|
  require(lib)
end

VIDEO_FILE = "downloaded_videos.yml"

class VimeoDownloader
  # include HTTParty
  # base_uri 'vimeo.com'
  # format :html
  USER_AGENT = "Mozilla/5.0"
  # headers "User-Agent" => USER_AGENT

  attr_reader :video_data, :video_id, :is_hd, :feed, :links, :downloaded_videos
  
  def initialize(trial=false)
    @trial = trial
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
      if download
        write_downloaded_videos_file unless defined?(@feed)
      end
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
      # download_link =  build_download_link
      if @trial
        print "  -- I would have downloaded this -- #{video_id}"
      else
        # command = %Q(wget -U "#{USER_AGENT}" -O #{filename} #{download_link})
        command = %Q(./vimeo_downloader.sh #{video_id})
        puts "******** downloading: #{command}"
        `#{command}`
        add_downloaded_video
      end  
      true
    else
      puts "********* already downloaded #{vimeo_video_url}"
      false
    end
  rescue => e
    puts "Error on video id #{video_id}: #{e.class}-- #{e.message}, #{e.backtrace}\n\n\n"
    false
  end


  # def get_xml_hash
  #   @xml_hash = HTTParty.get(xml).body
  #   if xml_hash.nil?
  #     STDERR.puts "xml_hash for #{video_id} was nil"
  #     nil
  #   else
  #     xml_hash
  #   end
  # end

  # def xml
  #   "http://www.vimeo.com/moogaloop/load/clip:#{video_id}"
  # end

  
  def get_feed(rss_feed)
    if rss_feed
      begin
        response = HTTParty.get(rss_feed)
        @feed = RSS::Parser.parse(response.body, false)
      rescue RSS::NotWellFormedError => e
        puts "#{e.class}\t#{e.message}\t#{rss_feed}\t#{e.backtrace.inspect}"
        # null object
        RSS::Rss.new('1.0')
      end  
    end
  end
  

  def get_links
    if feed
      @links = feed.items.map do |item| 
        item.link.scan(/[^\d](\d+)/)[-1]
      end.flatten
    end
  end 

  def reject_already_downloaded
    files = File.read("downloaded.txt").split("\n")
    rejected = links.reject! {|link| files.include?(link)}
  end

  def get_video_data
    # video_page = HTTParty.get("https://vimeo.com/#{video_id}", :headers => {"User-Agent" => USER_AGENT})
    # video_html = video_page.body
    response_filename = 'response.html'
    command = %Q(wget -U "#{USER_AGENT}" -O #{response_filename} http://vimeo.com/#{video_id})
    puts command
    `#{command}`
    video_html = File.read(response_filename)
    request_signature = video_html.scan(/"signature":"(.*?)"/i)[0][0]
    request_signature_expires = video_html.scan(/"timestamp":(\d*?),/i)[0][0]
    caption = video_html.scan(/"title":"(.*?)",/i)[0][0].gsub(/[^a-zA-Z0-9]/,'_')
    quality = video_html.scan(/"hd":(true|false)/i)[0][0] =~ /true/i ? 'hd' : 'sd'
# request_signature=`echo #{video_html}| perl -e '@text_in = <STDIN>; if (join(" ", @text_in) =~ /"signature":"(.*?)"/i ){ print "$1\n"; }'`
# request_signature_expires=`echo #{video_html} | perl -e '@text_in = <STDIN>; if (join(" ", @text_in) =~ /"timestamp":(\d*?),/i ){ print "$1\n"; }'`
# CAPTION=`echo $VIDEO_XML | perl -p -e 's:^.*?\<caption\>(.*?)\</caption\>.*$:$1:g'`
# ISHD=`echo $VIDEO_XML |  perl -p -e 's:^.*?\<isHD\>(.*?)\</isHD\>.*$:$1:g'`
    # video_html = Nokogiri::HTML(video_page.body)
    @video_data = OpenStruct.new(
      :video_id => video_id,
      :request_signature => request_signature, 
      :request_signature_expires => request_signature_expires,
      :caption => caption, 
      :quality => quality 
    )
    puts video_data.inspect
    video_data
  rescue => e
    STDERR.puts "ERROR on #{video_id}, #{e.backtrace}, #{e.class}, #{e.message}, #{video_data.inspect}"
    nil
  end

  def build_download_link
    if get_video_data.nil?
      ''
    else
# EXEC_CMD="${GET_CMD} http://player.vimeo.com/play_redirect?clip_id=${VIMEO_ID}&sig=${REQUEST_SIGNATURE}&time=${REQUEST_SIGNATURE_EXPIRES}&quality=hd&codecs=H264,VP8,VP6&type=moogaloop_local&embed_location=" 
    "http://player.vimeo.com/play_redirect?clip_id=#{video_data.video_id}&sig=#{video_data.request_signature}&time=#{video_data.request_signature_expires}&quality=#{video_data.quality}&codecs=H264,VP8,VP6&type=moogaloop_local&embed_location=" 
    end
  end

  # def set_video_quality
  #   puts "xml_hash" + xml_hash.inspect
  #   xml_data  = xml_hash["xml"]
  #   video_data = xml_data["video"]
  #   quality_setting = video_data["isHD"]
  #   @is_hd = (quality_setting == "1") ? "hd" : "sd"
  # rescue => e
  #   STDERR.puts "ERROR on #{video_id}, #{caller[0]}, #{e.class}, #{e.message}, #{video_data.inspect}"
  #   'sd'
  # end
  # def request_signature
  #   xml_hash["xml"]["request_signature"]
  # end

  # def request_signature_expires
  #   xml_hash["xml"]["request_signature_expires"]
  # end

  # def caption
  #   xml_hash["xml"]["video"]["caption"].gsub(/[^a-zA-Z0-9]/,'_')
  # end

  def file_extension
    (video_data.quality == "hd") ? "mp4" : "flv"
  end
  
  def filename
    "#{video_data.video_id}-#{video_data.caption}#{video_data.quality}.#{file_extension}"
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
