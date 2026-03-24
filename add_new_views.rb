require 'xcodeproj'

project_path = '/Users/josephngandu/Dev/Venda/Venda.xcodeproj'
project = Xcodeproj::Project.open(project_path)
target = project.targets.find { |t| t.name == 'Venda' } || project.targets.first

venda_group = project.main_group.children.find { |g| g.name == 'Venda' || g.path == 'Venda' }
views_group = venda_group.children.find { |g| g.name == 'Views' || g.path == 'Views' } || venda_group.new_group('Views', 'Views')

files_to_add = [
  '/Users/josephngandu/Dev/Venda/Venda/Views/PriceEntrySheet.swift',
  '/Users/josephngandu/Dev/Venda/Venda/Views/ReportsScreen.swift',
  '/Users/josephngandu/Dev/Venda/Venda/Views/PriceOverrideLogScreen.swift'
]

files_to_add.each do |path|
  existing_ref = views_group.children.find { |c| c.path == File.basename(path) }
  if existing_ref
    file_reference = existing_ref
    puts "#{path} already exists in project tree."
  else
    file_reference = views_group.new_file(path)
    puts "Added #{path} to project tree."
  end
  
  unless target.source_build_phase.files_references.include?(file_reference)
    target.add_file_references([file_reference])
    puts "Added #{path} to compile sources."
  end
end

project.save
puts "Successfully saved Venda.xcodeproj"
