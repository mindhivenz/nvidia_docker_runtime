
Facter.add('gpus') do
  setcode do
    Dir['/proc/driver/nvidia/gpus/*/information'].map { |info_file|
      File.readlines(info_file).map { |line|
        key, value = line.strip.split(/:\s*/, 2)
        [key.downcase.gsub(' ', '_'), value]
      }.to_h
    }
  end
end
