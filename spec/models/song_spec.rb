require 'rails_helper'

RSpec.describe Song, type: :model do
  it 'can create a valid song' do
    song = Song.create(
      artist: 'Artist Name',
      title: 'Song Title',
      release_year: 2000,
      spotify_uuid: 'some-spotify-uuid'
    )

    expect(song).to be_persisted
  end

  describe '#title' do
    it 'is required' do
      song = Song.new(title: nil)
      expect(song).not_to be_valid
      expect(song.errors[:title]).to include("can't be blank")
    end
  end

  describe '#artist' do
    it 'is required' do
      song = Song.new(artist: nil)
      expect(song).not_to be_valid
      expect(song.errors[:artist]).to include("can't be blank")
    end
  end

  describe '#release_year' do
    it 'is required' do
      song = Song.new(release_year: nil)
      expect(song).not_to be_valid
      expect(song.errors[:release_year]).to include("can't be blank")
    end

    it 'must be an integer' do
      song = Song.new(release_year: 1999.5)
      expect(song).not_to be_valid
      expect(song.errors[:release_year]).to include("must be an integer")
    end

    it 'must be greater than or equal to 1900' do
      song = Song.new(release_year: 1899)
      expect(song).not_to be_valid
      expect(song.errors[:release_year]).to include("must be greater than or equal to 1900")
    end

    it 'must be less than or equal to the current year' do
      song = Song.new(release_year: Date.current.year + 1)
      expect(song).not_to be_valid
      expect(song.errors[:release_year]).to include("must be less than or equal to #{Date.current.year}")
    end
  end

  describe '#spotify_uuid' do
    it 'is required' do
      song = Song.new(spotify_uuid: nil)
      expect(song).not_to be_valid
      expect(song.errors[:spotify_uuid]).to include("can't be blank")
    end
  end

  describe '#qr_token' do
    it 'is generated on creation' do
      song = Song.create(
        artist: 'Artist Name',
        title: 'Song Title',
        release_year: 2000,
        spotify_uuid: 'some-spotify-uuid'
      )
      expect(song.qr_token).to be_present
    end

    it 'is unique' do
      song1 = Song.create(
        artist: 'Artist One',
        title: 'First Song',
        release_year: 2001,
        spotify_uuid: 'uuid-1'
      )
      song2 = Song.create(
        artist: 'Artist Two',
        title: 'Second Song',
        release_year: 2002,
        spotify_uuid: 'uuid-2'
      )
      expect(song1.qr_token).not_to eq(song2.qr_token)
    end
  end
end
