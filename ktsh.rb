require 'json'
require 'tmpdir'

class Meta
  attr_reader :video_path, :thumbnail_count, :duration, :size, :resolution, :thumbnails

  def initialize(video_path, thumbnail_count)
    @video_path = video_path
    @thumbnail_count = thumbnail_count
    @thumbnails = []

    probe_video
    extract_thumbnails
  end

  private

  def probe_video
    command = %Q{ffprobe -v error -show_entries format=duration,size -show_entries stream=width,height -of json "#{@video_path}"}
    output = `#{command}`
    data = JSON.parse(output)

    @duration = data['format']['duration'].to_f
    @size = data['format']['size'].to_i

    video_stream = data['streams'].find { |s| s['width'] && s['height'] }
    @resolution = "#{video_stream['width']}x#{video_stream['height']}" if video_stream
  end

  def extract_thumbnails
    interval = (@duration - 10) / @thumbnail_count

    @thumbnail_count.times do |i|
      time_point = 5 + (i * interval)
      thumbnail_path = File.join(Dir.tmpdir, "thumbnail_#{i}.jpg")

      command = %Q{ffmpeg -ss #{time_point} -i "#{@video_path}" -vframes 1 -q:v 2 "#{thumbnail_path}" 2>/dev/null}
      system(command)

      @thumbnails << thumbnail_path if File.exist?(thumbnail_path)
    end
  end
end

Meta.new(ARGV[0], ARGV[1] || 48)
