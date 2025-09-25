module Pdf
  class DeckLayout
    Layout = Struct.new(:cols, :rows, :flip, keyword_init: true)
    Page   = Struct.new(:side, :cards) # side = :front or :back, cards = [song or nil]

    def initialize(songs, cols: 3, rows: 4, flip: :long)
      @songs = songs.to_a
      @layout = Layout.new(cols:, rows:, flip:)
    end

    def pages
      per_page = @layout.cols * @layout.rows
      @songs.each_slice(per_page).flat_map { |batch| pages_for_batch(batch, per_page) }
    end

    private

    def pages_for_batch(batch, per_page)
      padded = batch.dup
      padded.concat([ nil ] * (per_page - padded.size)) if padded.size < per_page

      front = Page.new(:front, padded)

      # compute back order for double-sided printing
      back_cards =
        if @layout.flip == :long
          padded.each_slice(@layout.cols).flat_map { |row| row.reverse }
        else # :short
          padded.each_slice(@layout.cols).to_a.reverse.flatten
        end

      back  = Page.new(:back, back_cards)

      [ front, back ]
    end
  end
end
