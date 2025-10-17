class PlaylistsController < ApplicationController
  skip_before_action :require_sign_in

  def cards
    @playlist = Playlist.find(params[:id])
    @songs    = @playlist.songs.order(:release_year)
    @pages    = Pdf::DeckLayout.new(@songs, cols: 3, rows: 4, flip: :long).pages

    respond_to do |format|
      format.html do
        render template: "playlists/cards", layout: "pdf_cards"
      end

      format.pdf do
        html = render_to_string(
          template: "playlists/cards",
          layout:   "pdf_cards",
          formats:  [ :html ]
        )
        pdf = Pdf::Exporter.new(html, wait_for_selector: ".cards-grid").to_pdf
        send_data pdf,
                  filename: "songs.pdf",
                  type: "application/pdf",
                  disposition: "inline"
      end
    end
  end
end
