require 'xcodeproj'

project_path = '/Users/josephngandu/Dev/Venda/Venda.xcodeproj'
project = Xcodeproj::Project.open(project_path)
target = project.targets.find { |t| t.name == 'Venda' } || project.targets.first

venda_group = project.main_group.children.find { |g| g.name == 'Venda' || g.path == 'Venda' }
unless venda_group
  puts "Venda group not found"
  exit 1
end

services_group = venda_group.children.find { |g| g.name == 'Services' || g.path == 'Services' } || venda_group.new_group('Services', 'Services')
models_group = venda_group.children.find { |g| g.name == 'Models' || g.path == 'Models' } || venda_group.new_group('Models', 'Models')
views_group = venda_group.children.find { |g| g.name == 'Views' || g.path == 'Views' } || venda_group.new_group('Views', 'Views')

files_to_add = {
  '/Users/josephngandu/Dev/Venda/Venda/Services/NetworkService.swift' => services_group,
  '/Users/josephngandu/Dev/Venda/Venda/Services/SyncEngine.swift' => services_group,
  '/Users/josephngandu/Dev/Venda/Venda/Models/CoreDataManager.swift' => models_group,
  '/Users/josephngandu/Dev/Venda/Venda/Views/VendaTabBar.swift' => views_group
}

files_to_add.each do |path, group|
  # Avoid adding duplicates
  existing_ref = group.children.find { |c| c.path == File.basename(path) }
  if existing_ref
    file_reference = existing_ref
    puts "#{path} already exists in project tree."
  else
    file_reference = group.new_file(path)
    puts "Added #{path} to project tree."
  end
  
  # Ensure it is compiled in the target
  unless target.source_build_phase.files_references.include?(file_reference)
    target.add_file_references([file_reference])
    puts "Added #{path} to compile sources phase."
  end
end

project.save
puts "Successfully saved Venda.xcodeproj"
