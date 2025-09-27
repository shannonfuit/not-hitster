require "yaml"

songs_data = YAML.load_file(Rails.root.join("db", "seeds", "songs.yml"))

songs_data.each do |attrs|
  Song.find_or_create_by!(qr_token: attrs["qr_token"]) do |song|
    song.artist       = attrs["artist"]
    song.title        = attrs["title"]
    song.release_year = attrs["release_year"]
    song.spotify_uuid = attrs["spotify_uuid"]
  end
end
