# frozen_string_literal: true

require 'yaml'

files = Dir['.github/workflows/*.{yml,yaml}', '.github/actions/**/action.{yml,yaml}']
abort 'No workflows found' if files.empty?

errors = []
files.sort.each do |file|
  document = YAML.safe_load(File.read(file), aliases: true)
  jobs = document.fetch('jobs', {})
  steps = jobs.values.flat_map { |job| job.fetch('steps', []) }
  steps.concat(document.fetch('runs', {}).fetch('steps', []))
  (steps + jobs.values).each do |entry|
    ref = entry['uses']
    next unless ref
    next if ref.start_with?('./')
    next if ref.match?(%r{\A[\w.-]+/[\w./-]+@[0-9a-f]{40}\z})
    next if ref.match?(%r{\Adocker://[^@\s]+@sha256:[0-9a-f]{64}\z})

    errors << "#{file}: pin #{ref.inspect} to a full upstream commit or container digest"
  end
  jobs.each_value do |job|
    ([job['container']] + job.fetch('services', {}).values).compact.each do |service|
      image = service.is_a?(String) ? service : service.fetch('image')
      errors << "#{file}: pin container #{image.inspect} to a digest" unless image.match?(/@sha256:[0-9a-f]{64}\z/)
    end
  end
end
abort errors.join("\n") unless errors.empty?
puts "Verified action and container pins in #{files.size} workflow/action files."
