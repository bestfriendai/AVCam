#!/usr/bin/env ruby
require 'xcodeproj'

project_path = 'AVCam.xcodeproj'
project = Xcodeproj::Project.open(project_path)

# Find the AVCam target
target = project.targets.find { |t| t.name == 'AVCam' }

# Find the Model group
model_group = project.main_group.find_subpath('AVCam/Model', true)

# Add the new files
new_files = [
  'AVCam/Model/CameraSessionState.swift',
  'AVCam/Model/CameraFeedback.swift'
]

new_files.each do |file_path|
  file_ref = model_group.new_reference(file_path)
  target.add_file_references([file_ref])
end

project.save
puts "Files added successfully!"
