#!/usr/bin/env ruby
require 'xcodeproj'

project_path = 'AVCam.xcodeproj'
project = Xcodeproj::Project.open(project_path)

# Find the AVCam target (not the extensions)
avcam_target = project.targets.find { |t| t.name == 'AVCam' }
raise "AVCam target not found" unless avcam_target

# Find the AVCamCaptureExtension target (Camera.swift is in this too)
extension_target = project.targets.find { |t| t.name == 'AVCamCaptureExtension' }
raise "AVCamCaptureExtension target not found" unless extension_target

# Find the Model group
model_group = project.main_group.find_subpath('AVCam/Model')
raise "Model group not found" unless model_group

# Files to add (just the filenames, not full paths)
files_to_add = [
  'CameraSessionState.swift',
  'CameraFeedback.swift'
]

files_to_add.each do |filename|
  # Check if file already exists in project
  existing = model_group.files.find { |f| f.path == filename }

  if existing
    puts "File #{filename} already exists in project"
    # Make sure it's in both targets
    [avcam_target, extension_target].each do |target|
      unless target.source_build_phase.files.any? { |bf| bf.file_ref == existing }
        target.add_file_references([existing])
        puts "  Added to #{target.name} target"
      else
        puts "  Already in #{target.name} target"
      end
    end
  else
    # Add file reference to the group
    file_ref = model_group.new_reference(filename)

    # Add file to both targets (since Camera.swift is in both)
    [avcam_target, extension_target].each do |target|
      target.add_file_references([file_ref])
      puts "Added #{filename} to #{target.name} target"
    end
  end
end

# Save the project
project.save

puts "\n✅ Files added successfully to Xcode project!"
puts "You can now build the project."

