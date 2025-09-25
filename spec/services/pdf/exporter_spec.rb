# spec/services/pdf/exporter_spec.rb
require "rails_helper"

RSpec.describe Pdf::Exporter do
  it "delegates to Grover with defaults and returns bytes" do
    html = "<html><body>hi</body></html>"
    fake_pdf = "PDF_BYTES"

    grover_double = instance_double(Grover, to_pdf: fake_pdf)
    expect(Grover).to receive(:new)
      .with(html, hash_including(:timeout, :format, :emulate_media))
      .and_return(grover_double)

    bytes = described_class.new(html).to_pdf
    expect(bytes).to eq(fake_pdf)
  end
end
