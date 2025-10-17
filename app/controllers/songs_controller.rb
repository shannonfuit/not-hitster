class SongsController < ApplicationController
  skip_before_action :require_sign_in
  def lookup
    song = Song.find_by(qr_token: params[:qr_token])
    if song&.spotify_uuid.present?
      render json: { spotify_uuid: song.spotify_uuid }
    else
      head :not_found
    end
  end

  def index
    @songs = Song.all
  end
end
