#!/usr/bin/env ruby
require 'xcodeproj'

project_path = 'AVCam.xcodeproj'
project = Xcodeproj::Project.open(project_path)

# Find targets
avcam_target = project.targets.find { |t| t.name == 'AVCam' }
extension_target = project.targets.find { |t| t.name == 'AVCamCaptureExtension' }

raise "AVCam target not found" unless avcam_target
raise "AVCamCaptureExtension target not found" unless extension_target

# Find the Model group
model_group = project.main_group.find_subpath('AVCam/Model')
raise "Model group not found" unless model_group

# Files to add
files_to_add = ['CameraSessionState.swift', 'CameraFeedback.swift']

files_to_add.each do |filename|
  puts "\nProcessing #{filename}..."
  
  # Check if file reference already exists in the Model group
  existing_ref = model_group.files.find { |f| f.path == filename }
  
  if existing_ref
    puts "  File reference already exists"
    file_ref = existing_ref
  else
    # Create new file reference
    file_ref = model_group.new_reference(filename)
    puts "  Created new file reference"
  end
  
  # Add to AVCam target if not already there
  if avcam_target.source_build_phase.files.any? { |bf| bf.file_ref == file_ref }
    puts "  Already in AVCam target"
  else
    avcam_target.add_file_references([file_ref])
    puts "  ✅ Added to AVCam target"
  end
  
  # Add to AVCamCaptureExtension target if not already there
  if extension_target.source_build_phase.files.any? { |bf| bf.file_ref == file_ref }
    puts "  Already in AVCamCaptureExtension target"
  else
    extension_target.add_file_references([file_ref])
    puts "  ✅ Added to AVCamCaptureExtension target"
  end
end

# Save the project
project.save

puts "\n✅ Done! Files are now in the Xcode project."

