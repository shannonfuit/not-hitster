require "rails_helper"

RSpec.describe User, type: :model do
  describe "#token_expired?" do
    it "returns true when token_expires_at is in the past" do
      user = described_class.new(token_expires_at: 1.minute.ago)
      expect(user.token_expired?).to be true
    end

    it "returns false when token_expires_at is in the future" do
      user = described_class.new(token_expires_at: 5.minutes.from_now)
      expect(user.token_expired?).to be false
    end

    it "returns false when token_expires_at is nil" do
      user = described_class.new
      expect(user.token_expired?).to be false
    end
  end
end
