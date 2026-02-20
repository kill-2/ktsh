require 'json'
require 'tmpdir'
require 'securerandom'
require 'fileutils'
require 'optparse'

module Ktsh
  class Meta
    attr_reader :video_path, :samples, :width, :duration, :size, :resolution, :tmpdir

    def initialize(video_path, samples, width)
      @video_path = video_path
      @samples = samples
      @width = width
      @tmpdir = FileUtils.mkdir_p(File.join(Dir.tmpdir, 'ktsh', SecureRandom.uuid))[0]

      probe_video
      extract_thumbnails
    end

    def info_file
      File.join(tmpdir, 'info.txt').tap do |name|
        File.open(name, 'w') do |f|
          f.puts "名称: #{File.basename(video_path)}\n体积: #{human_size(size)}\n尺寸: #{resolution}\n时长: #{human_time(duration)}"
        end
      end
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
      interval = (duration - 10) / @samples

      @samples.times do |i|
        seq = i.to_s.rjust(3, '0')
        time_point = 5 + (i * interval)
        time_point_str = human_time(time_point)
        thumbnail_path = File.join(tmpdir, "#{seq}.jpg")

        command = %Q{ffmpeg -ss #{time_point} -i "#{@video_path}" -vf "scale=#{width}:-1,drawtext=text='#{time_point_str}':fontcolor=white:fontsize=12:shadowcolor=black@0.7:shadowx=2:shadowy=2:x=w-tw-10:y=h-th-10" -vframes 1 -q:v 2 "#{thumbnail_path}" 2>/dev/null}
        system(command)
      end
    end

    def human_time(time)
      '%02d\:%02d\:%02d' % [time / 3600, time / 60 % 60, time % 60]
    end

    def human_size(size)
      ['B', 'KB', 'MB', 'GB'].each_with_index.lazy.
        map{|unit, idx| [(size.to_f / (1024 ** idx)).round(2), unit]}.
        select{|n, unit| n < 1024}.
        first.join
    end
  end

  class << self
    def create(video, horizontal: 8, vertical: 6, width: 2560, padding: 2)
      start = Time.now
      lock = Mutex.new
      stop = false
      Thread.new{ loop{ break if lock.synchronize{stop}; print "\r#{start.strftime('%T')}~#{Time.now.strftime('%T')} #{File.basename(video)}"; sleep 1 } }

      sample_width = (width - ((horizontal - 1) * padding) - 4) / horizontal
      meta = Meta.new(video, horizontal * vertical, sample_width)
      command = %Q{ffmpeg -pattern_type glob -i "#{meta.tmpdir}/*.jpg" -filter_complex "tile=#{horizontal}x#{vertical}:padding=#{padding}:color=white,pad=iw+4:ih+102:2:100:white,drawtext=textfile='#{meta.info_file}':fontsize=18:fontcolor=black:x=2:y=2,format=yuv420p" -q:v 2 "#{video}.jpg" 2>/dev/null}
      system(command)

      lock.synchronize{stop = true}
      puts
    end
  end
end

options = {}
OptionParser.new do |opts|
  opts.banner = "Usage: ktsh.rb [options] <video>"
  opts.on('-h', '--horizontal NUM', Integer)
  opts.on('-v', '--vertical NUM', Integer)
  opts.on('-w', '--width NUM', Integer)
end.parse!(into: options)

video = ARGV[0]
abort("Error: video file required") unless video

Ktsh.create(video, **options)
