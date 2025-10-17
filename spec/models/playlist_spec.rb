require 'rails_helper'

RSpec.describe Playlist, type: :model do
  it 'can create a valid playlist' do
    playlist = Playlist.create(name: 'My Playlist', spotify_url: 'https://open.spotify.com/playlist/12345')

    expect(playlist).to be_persisted
  end

  describe '#name' do
    it 'is required' do
      playlist = Playlist.new(name: nil)
      expect(playlist).not_to be_valid
      expect(playlist.errors[:name]).to include("can't be blank")
    end

    it 'must be unique' do
      Playlist.create(name: 'Unique Playlist', spotify_url: 'https://open.spotify.com/playlist/12345')
      duplicate = Playlist.new(name: 'Unique Playlist', spotify_url: 'https://open.spotify.com/playlist/12345')
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:name]).to include("has already been taken")
    end
  end

  describe '#spotify_url' do
    it 'is required' do
      playlist = Playlist.new(spotify_url: nil)
      expect(playlist).not_to be_valid
      expect(playlist.errors[:spotify_url]).to include("can't be blank")
    end
  end

  # add tests to create a playlist with a song
  describe 'associations' do
    it 'can have many songs through playlist_songs' do
      playlist = Playlist.create(name: 'My Playlist', spotify_url: 'https://open.spotify.com/playlist/12345')
      song1 = Song.create(artist: 'Artist 1', title: 'Song 1', release_year: 2001, spotify_uuid: 'uuid-1')
      song2 = Song.create(artist: 'Artist 2', title: 'Song 2', release_year: 2002, spotify_uuid: 'uuid-2')

      playlist.playlist_songs.create(song: song1)
      playlist.playlist_songs.create(song: song2)

      expect(playlist.songs).to include(song1, song2)
    end

    it 'does not delete songs when playlist is deleted' do
      playlist = Playlist.create(name: 'My Playlist', spotify_url: 'https://open.spotify.com/playlist/12345')
      song = Song.create(artist: 'Artist', title: 'Song', release_year: 2000, spotify_uuid: 'uuid')

      playlist.playlist_songs.create(song: song)
      playlist.destroy

      expect(Song.exists?(song.id)).to be true
    end
  end
end
