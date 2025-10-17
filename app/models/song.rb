class Song < ApplicationRecord
  has_many :playlist_songs, dependent: :destroy
  has_many :playlists, through: :playlist_songs
  validates :artist, presence: true
  validates :title, presence: true
  validates :release_year, presence: true,
    numericality: {
      only_integer: true,
      greater_than_or_equal_to: 1900,
      less_than_or_equal_to: Date.current.year
    }
  validates :spotify_uuid, presence: true

  has_secure_token :qr_token
  validates :qr_token, presence: true, uniqueness: true
end
