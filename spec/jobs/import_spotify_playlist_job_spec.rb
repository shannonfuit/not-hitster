# spec/jobs/import_spotify_playlist_job_spec.rb
require "rails_helper"

RSpec.describe ImportSpotifyPlaylistJob, type: :job do
  let(:user) do
    User.create!(
      spotify_uid: "user123",
      display_name: "Test User",
      email: "test@test.nl",
      access_token: "token123",
      refresh_token: "refresh123",
      token_expires_at: 1.hour.from_now
    )
  end
  let(:playlist_url)  { "https://open.spotify.com/playlist/PL123ABC" }
  let(:token)         { "access_token_123" }
  let(:token_provider) { instance_double(Spotify::TokenProvider) }
  let(:client)        { instance_double(Spotify::Client) }

  before do
    allow(Spotify::TokenProvider).to receive(:new).with(user).and_return(token_provider)
    allow(token_provider).to receive(:access_token!).and_return(token)
    allow(Spotify::Client).to receive(:new).with(token).and_return(client)
  end

  def track_item(id:, name:, artist:, release_date: nil)
    {
      "track" => {
        "id"      => id,
        "name"    => name,
        "artists" => [ { "name" => artist } ],
        "album"   => (release_date ? { "release_date" => release_date } : {})
      }
    }
  end

  describe ".queue_as" do
    it "uses the default queue" do
      expect(described_class.queue_name).to eq("default")
    end
  end

  describe "#perform" do
    it "creates valid songs and skips those missing/invalid release_year; logs totals" do
      valid   = track_item(id: "s1", name: "Song A", artist: "Artist A", release_date: "1999-05-01")
      missing = track_item(id: "s2", name: "Song B", artist: "Artist B")               # no release_date -> skip
      zero    = track_item(id: "s3", name: "Song C", artist: "Artist C", release_date: "0000-01-01") # invalid -> skip

      expect(client).to receive(:each_playlist_track).with(playlist_url)
        .and_yield(valid).and_yield(missing).and_yield(zero)

      # expect warnings for the two skipped due to invalid/missing year
      expect(Rails.logger).to receive(:warn).with(
        /skip: invalid release_year .* track="s2".*release_date=nil/i
      )
      expect(Rails.logger).to receive(:warn).with(
        /skip: invalid release_year .* track="s3".*release_date="0000-01-01"/i
      )

      expect(Rails.logger).to receive(:info)
        .with(/\[ImportSpotifyPlaylistJob\] user=#{user.id} created=1 updated=0 skipped=2/)

      expect {
        described_class.new.perform(user_id: user.id, playlist_url: playlist_url)
      }.to change(Song, :count).by(1)

      s1 = Song.find_by!(spotify_uuid: "s1")
      expect(s1.title).to eq("Song A")
      expect(s1.artist).to eq("Artist A")
      expect(s1.release_year).to eq(1999)
      expect(Song.where(spotify_uuid: %w[s2 s3])).to be_empty
    end

    it "updates existing songs when attributes change (with valid year)" do
      song = Song.create!(spotify_uuid: "s1", title: "Old", artist: "Old Artist", release_year: 1980)
      item = track_item(id: "s1", name: "New Title", artist: "New Artist", release_date: "2002-10-10")

      expect(client).to receive(:each_playlist_track).and_yield(item)
      expect(Rails.logger).to receive(:info)
        .with(/\bcreated=0 updated=1 skipped=0\b/)

      expect {
        described_class.new.perform(user_id: user.id, playlist_url: playlist_url)
      }.not_to change(Song, :count)

      song.reload
      expect(song.title).to eq("New Title")
      expect(song.artist).to eq("New Artist")
      expect(song.release_year).to eq(2002)
    end

    it "skips unchanged songs (valid year present)" do
      Song.create!(spotify_uuid: "s1", title: "Same", artist: "Artist X", release_year: 2020)
      item = track_item(id: "s1", name: "Same", artist: "Artist X", release_date: "2020-01-01")

      expect(client).to receive(:each_playlist_track).and_yield(item)
      expect(Rails.logger).to receive(:info)
        .with(/\bcreated=0 updated=0 skipped=1\b/)

      expect {
        described_class.new.perform(user_id: user.id, playlist_url: playlist_url)
      }.not_to change(Song, :count)
    end

    it "increments skipped for items without a 'track' payload" do
      bad_item = { "foo" => "bar" }
      expect(client).to receive(:each_playlist_track).and_yield(bad_item)

      expect(Rails.logger).to receive(:info)
        .with(/\bcreated=0 updated=0 skipped=1\b/)

      described_class.new.perform(user_id: user.id, playlist_url: playlist_url)
    end

    it "ignores items missing id/title/artist (no counters increment)" do
      missing_id     = track_item(id: nil,      name: "A",   artist: "B", release_date: "2001-01-01")
      missing_title  = track_item(id: "s2",     name: "",    artist: "B", release_date: "2002-01-01")
      missing_artist = track_item(id: "s3",     name: "A",   artist: "",  release_date: "2003-01-01")

      expect(client).to receive(:each_playlist_track)
        .and_yield(missing_id).and_yield(missing_title).and_yield(missing_artist)

      expect(Rails.logger).to receive(:info)
        .with(/\bcreated=0 updated=0 skipped=0\b/)

      expect {
        described_class.new.perform(user_id: user.id, playlist_url: playlist_url)
      }.not_to change(Song, :count)
    end

    it "skips and warns when release_year parses to non-positive" do
      item = track_item(id: "s1", name: "Zero Year", artist: "Z", release_date: "0000-01-01")
      expect(client).to receive(:each_playlist_track).and_yield(item)

      expect(Rails.logger).to receive(:warn).with(
        /skip: invalid release_year .* track="s1".*release_date="0000-01-01"/i
      )
      expect(Rails.logger).to receive(:info)
        .with(/\bcreated=0 updated=0 skipped=1\b/)

      expect {
        described_class.new.perform(user_id: user.id, playlist_url: playlist_url)
      }.not_to change(Song, :count)

      expect(Song.find_by(spotify_uuid: "s1")).to be_nil
    end

    it "skips and warns when validations fail on save! for other reasons" do
      valid = track_item(id: "s1", name: "Valid", artist: "A", release_date: "2001-01-01")

      # Make the client yield our valid track
      expect(client).to receive(:each_playlist_track).and_yield(valid)

      # Return a specific Song instance that the job will try to save
      song = Song.new(spotify_uuid: "s1", title: "Valid", artist: "A", release_year: 2001)
      allow(Song).to receive(:find_or_initialize_by).with(spotify_uuid: "s1").and_return(song)

      # Force a validation failure on save!, with an error we can assert on
      allow(song).to receive(:save!).and_raise(
        ActiveRecord::RecordInvalid.new(song.tap { |s| s.errors.add(:base, "boom") })
      )

      # Use a_string_matching and match "errors=boom" (no space before boom)
      expect(Rails.logger).to receive(:warn)
        .with(a_string_matching(/skip: validation failed .*errors=.*boom/i))

      expect(Rails.logger).to receive(:info)
        .with(/\bcreated=0 updated=0 skipped=1\b/)

      expect {
        described_class.new.perform(user_id: user.id, playlist_url: playlist_url)
      }.not_to change(Song, :count)
    end
  end
end
