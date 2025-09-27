namespace :songs do
  desc "Dump songs to db/seeds/songs.yml (override with FILE=... and FORMAT=yaml|json)"
  task dump: :environment do
    require "yaml"
    require "json"
    require "fileutils"

    file   = (ENV["FILE"] || Rails.root.join("db", "seeds", "songs.yml")).to_s
    format = (ENV["FORMAT"] || File.extname(file).delete(".") || "yml").downcase

    columns = %w[artist title release_year spotify_uuid qr_token]
    rows = Song.pluck(*columns).map { |vals| columns.zip(vals).to_h }

    FileUtils.mkdir_p(File.dirname(file))

    case format
    when "yaml", "yml"
      File.write(file, rows.to_yaml)
    when "json"
      File.write(file, JSON.pretty_generate(rows))
    else
      abort "Unsupported FORMAT: #{format.inspect}. Use yaml or json."
    end

    puts "✅ Dumped #{rows.size} songs to #{file}"
  end
end
