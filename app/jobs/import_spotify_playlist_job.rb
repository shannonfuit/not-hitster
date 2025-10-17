class ImportSpotifyPlaylistJob < ApplicationJob
  queue_as :default

  def perform(user_id:, playlist_id:)
    user      = User.find(user_id)
    playlist  = Playlist.find(playlist_id)

    access_token = Spotify::TokenProvider.new(user).access_token!
    client       = Spotify::Client.new(access_token)

    created = 0
    updated = 0
    skipped = 0
    linked  = 0

    client.each_playlist_track(playlist.spotify_url) do |item|
      track = item["track"]
      unless track
        skipped += 1
        next
      end

      spotify_uuid     = track["id"]
      title            = track["name"].to_s
      artist_name      = (track["artists"]&.first&.dig("name")).to_s
      raw_release_date = track.dig("album", "release_date")
      release_date     = raw_release_date.to_s

      unless spotify_uuid.present? && title.present? && artist_name.present?
        skipped += 1
        next
      end

      release_year = release_date.present? ? release_date[0, 4].to_i : 0
      unless release_year.positive?
        Rails.logger.warn(
          "[ImportSpotifyPlaylistJob] skip: invalid release_year " \
          "user=#{user.id} track=#{spotify_uuid.inspect} title=#{title.inspect} " \
          "artist=#{artist_name.inspect} release_date=#{raw_release_date.inspect}"
        )
        skipped += 1
        next
      end

      song = Song.find_or_initialize_by(spotify_uuid: spotify_uuid)
      song.title        = title
      song.artist       = artist_name
      song.release_year = release_year

      if song.changed?
        begin
          song.save!
          song.previous_changes.key?("id") ? created += 1 : updated += 1
        rescue ActiveRecord::RecordInvalid => e
          msgs = e.record.respond_to?(:errors) ? e.record.errors.full_messages.join(", ") : e.message
          Rails.logger.warn(
            "[ImportSpotifyPlaylistJob] skip: validation failed user=#{user.id} track=#{spotify_uuid.inspect} " \
            "title=#{title.inspect} artist=#{artist_name.inspect} errors=#{msgs}"
          )
          skipped += 1
          next
        end
      else
        skipped += 1
      end

      if PlaylistSong.find_or_create_by!(playlist:, song:)
        linked += 1
      end
    end

    Rails.logger.info(
      "[ImportSpotifyPlaylistJob] user=#{user.id} playlist_id=#{playlist.id} " \
      "created=#{created} updated=#{updated} skipped=#{skipped} linked=#{linked}"
    )
  end
end
