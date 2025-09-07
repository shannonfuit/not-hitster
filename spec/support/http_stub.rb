# A tiny helper to stub Net::HTTP.start without adding WebMock.

require "ostruct"

module HttpStub
  FakeHttp = Struct.new(:body) do
    def request(_req)
      OpenStruct.new(body: body)
    end
  end

  def with_http_stub(json_string)
    allow(Net::HTTP).to receive(:start).and_wrap_original do |_, *args, **kwargs, &blk|
      blk.call(FakeHttp.new(json_string))
    end
    yield
  ensure
    allow(Net::HTTP).to receive(:start).and_call_original
  end
end
  