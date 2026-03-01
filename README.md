# ktsh.rb

A Ruby script that generates a video contact sheet by extracting evenly-spaced frames from a video file and compositing them into a tiled grid image.

## Usage

```bash
ruby ktsh.rb [options] <video_file>
```

### Options

- `-h, --horizontal NUM` - Number of columns in the grid (default: 8)
- `-v, --vertical NUM` - Number of rows in the grid (default: 6)
- `-w, --width NUM` - Width of final image in pixels (default: 2560)

### Examples

```bash
# Basic usage - creates 8x6 grid
ruby ktsh.rb video.mp4

# Create 4x4 grid with smaller thumbnails
ruby ktsh.rb -h 4 -v 4 -w 1280 video.mp4
```

## License

No license specified.
