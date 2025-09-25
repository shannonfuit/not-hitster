require "rails_helper"

RSpec.describe "Songs cards PDF", type: :request do
  before do
    5.times do |i|
      Song.create!(
        artist: "Artist #{i+1}",
        title: "Title #{i+1}",
        release_year: 2000 + i,
        spotify_uuid: "sp#{i+1}"
      )
    end
  end

  describe "GET /songs/cards.html" do
    it "renders the HTML with cards grid" do
      get cards_songs_path(format: :html)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("cards-grid")
      # smoke check: includes a song value
      expect(response.body).to include("Artist 1")
    end
  end

  describe "GET /songs/cards.pdf" do
    it "returns a PDF by invoking the exporter on the rendered HTML" do
      # Arrange: stub Pdf::Exporter so no real Grover/Chromium is launched
      fake_pdf = "%PDF-1.4\n%stub\n"
      exporter_double = instance_double(Pdf::Exporter, to_pdf: fake_pdf)

      expect(Pdf::DeckLayout).to receive(:new).and_call_original
      expect(Pdf::Exporter).to receive(:new)
        .with(kind_of(String), hash_including(:wait_for_selector))
        .and_return(exporter_double)

      get cards_songs_path(format: :pdf)

      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq("application/pdf")
      expect(response.body.start_with?("%PDF")).to be(true)
      expect(response.headers["Content-Disposition"]).to include("inline")
    end
  end
end
