class Playlist < ApplicationRecord
  has_many :playlist_songs, dependent: :destroy
  has_many :songs, through: :playlist_songs

  validates :name, presence: true, uniqueness: true
  validates :spotify_url, presence: true

  BARTS_HITS_TITLE = "Bart's Hits"

  def barts_hits?
    name == BARTS_HITS_TITLE
  end
end
