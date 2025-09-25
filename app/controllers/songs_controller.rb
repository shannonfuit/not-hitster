class SongsController < ApplicationController
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

  def cards
    @songs = Song.all
    @pages = Pdf::DeckLayout.new(@songs, cols: 3, rows: 4, flip: :long).pages

    respond_to do |format|
      format.html do
        render template: "songs/cards", layout: "pdf_cards"
      end

      format.pdf do
        html = render_to_string(
          template: "songs/cards",
          layout:   "pdf_cards",
          formats:  [ :html ]
        )

        pdf  = Pdf::Exporter.new(
          html,
          wait_for_selector: ".cards-grid"
        ).to_pdf

        send_data pdf,
                filename: "songs.pdf",
                type: "application/pdf",
                disposition: "inline"
      end
    end
  end
end
