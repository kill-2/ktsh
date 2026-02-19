require 'json'
require 'tmpdir'
require 'securerandom'
require 'fileutils'

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
    tmpdir = FileUtils.mkdir_p(File.join(Dir.tmpdir, 'ktsh', SecureRandom.uuid))[0]
    interval = (@duration - 10) / @thumbnail_count

    @thumbnail_count.times do |i|
      seq = i.to_s.rjust(3, '0')
      time_point = 5 + (i * interval)
      time_point_str = '%02d\:%02d\:%02d' % [time_point / 3600, time_point / 60 % 60, time_point % 60]
      thumbnail_path = File.join(tmpdir, "#{seq}.jpg")

      command = %Q{ffmpeg -ss #{time_point} -i "#{@video_path}" -vf "scale=640:-1,drawtext=text='#{time_point_str}':fontcolor=white:fontsize=12:shadowcolor=black@0.7:shadowx=2:shadowy=2:x=w-tw-10:y=h-th-10" -vframes 1 -q:v 2 "#{thumbnail_path}" 2>/dev/null}
      system(command)

      @thumbnails << thumbnail_path if File.exist?(thumbnail_path)
    end
  end
end

meta = Meta.new(ARGV[0], ARGV[1] || 48)
p meta
