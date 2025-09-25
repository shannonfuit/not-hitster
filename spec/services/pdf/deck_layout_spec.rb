
require "rails_helper"

RSpec.describe Pdf::DeckLayout do
  SongStub = Struct.new(:id, :artist, :title, :release_year, :spotify_uuid)

  def songs(n)
    Array.new(n) do |i|
      SongStub.new(i + 1, "Artist #{i+1}", "Title #{i+1}", 2000 + i, "sp#{i+1}")
    end
  end

  let(:cols) { 3 }
  let(:rows) { 4 }
  let(:per_page) { cols * rows }

  context "exactly one full batch (12)" do
    it "returns 2 pages (front+back) with 12 cards each" do
      layout = described_class.new(songs(per_page), cols:, rows:, flip: :long)
      pages  = layout.pages

      expect(pages.size).to eq(2)
      expect(pages[0].side).to eq(:front)
      expect(pages[1].side).to eq(:back)
      expect(pages[0].cards.size).to eq(per_page)
      expect(pages[1].cards.size).to eq(per_page)
      # front keeps order
      expect(pages[0].cards.compact.map(&:id)).to eq((1..12).to_a)
    end

    it "computes back order correctly for :long flip (reverse columns within each row)" do
      layout = described_class.new(songs(per_page), cols:, rows:, flip: :long)
      pages  = layout.pages
      back   = pages[1].cards.compact.map(&:id)

      # front rows: [1,2,3], [4,5,6], [7,8,9], [10,11,12]
      # back rows (reversed cols): [3,2,1], [6,5,4], [9,8,7], [12,11,10]
      expect(back).to eq([3,2,1, 6,5,4, 9,8,7, 12,11,10])
    end

    it "computes back order correctly for :short flip (reverse row order, keep columns)" do
      layout = described_class.new(songs(per_page), cols:, rows:, flip: :short)
      pages  = layout.pages
      back   = pages[1].cards.compact.map(&:id)

      # reverse rows: [10,11,12], [7,8,9], [4,5,6], [1,2,3]
      expect(back).to eq([10,11,12, 7,8,9, 4,5,6, 1,2,3])
    end
  end

  context "incomplete last batch (14 total => 12 + 2 padded)" do
    it "pads last batch to 12 so grid/back alignment stays consistent" do
      layout = described_class.new(songs(14), cols:, rows:, flip: :long)
      pages  = layout.pages

      # 14 items => 2 batches -> 4 pages (front+back per batch)
      expect(pages.size).to eq(4)

      last_front = pages[2]
      last_back  = pages[3]

      expect(last_front.side).to eq(:front)
      expect(last_back.side).to eq(:back)

      # last front has first 2 real songs (13,14), then 10 nils (padding)
      front_ids = last_front.cards.map { |s| s&.id }
      expect(front_ids.first(2)).to eq([13,14])
      expect(front_ids.drop(2).all?(&:nil?)).to be(true)

      # back page uses the same padded set, reordered by flip; still 12 cells
      expect(last_back.cards.size).to eq(per_page)
    end
  end
end
