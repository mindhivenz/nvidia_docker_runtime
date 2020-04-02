
Facter.add('gpus') do
  setcode do
    Dir['/proc/driver/nvidia/gpus/*/information'].map do |info_file|
      File.readlines(info_file).map { |line|
        key, value = line.strip.split(%r{:\s*}, 2)
        [key.downcase.tr(' ', '_'), value]
      }.to_h
    end
  end
end
