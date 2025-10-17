# frozen_string_literal: true

namespace :songs do
  desc "Dump songs and playlists to JSON (db/seeds/songs.json)"
  task dump: :environment do
    require "json"
    require "fileutils"

    songs_path = Rails.root.join("db", "seeds", "songs.json")
    FileUtils.mkdir_p(songs_path.dirname)

    songs_rows = []
    Song.includes(:playlists).find_each do |song|
      songs_rows << {
        "artist"        => song.artist,
        "title"         => song.title,
        "release_year"  => song.release_year,
        "spotify_uuid"  => song.spotify_uuid,
        "qr_token"      => song.qr_token,
        "playlists"     => song.playlists.order(:name).map do |pl|
          { "name" => pl.name, "spotify_url" => pl.spotify_url }
        end
      }
    end

    File.write(songs_path, JSON.pretty_generate(songs_rows))

    puts "✅ Dumped #{songs_rows.size} songs -> #{songs_path}"
  end
end
