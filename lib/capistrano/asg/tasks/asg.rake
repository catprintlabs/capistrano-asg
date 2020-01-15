require 'capistrano/asg'

namespace :asg do
  task :scale do
    set :aws_access_key_id,     fetch(:aws_access_key_id,     ENV['AWS_ACCESS_KEY_ID'])
    set :aws_secret_access_key, fetch(:aws_secret_access_key, ENV['AWS_SECRET_ACCESS_KEY'])
    asg_launch_config = {}
    asg_launch_templates = {}
    asg_ami_id = {}

    # Iterate over relevant regions
    regions = fetch(:regions)
    regions.keys.each do |region|
      set :aws_region, region
      asg_launch_config[region] = {}
      asg_launch_templates[region] = {}
      asg_ami_id[region] = {}

      # Iterate over relevant ASGs
      regions[region].each do |asg|
        set :aws_autoscale_group, asg
        Capistrano::Asg::AMI.create do |ami|
          puts "Autoscaling: Created AMI: #{ami.aws_counterpart.id} from region #{region} in ASG #{asg}"
          asg_ami_id[region][asg] = ami.aws_counterpart.id

          if (template_name = fetch(:launch_template_name))
            Capistrano::Asg::LaunchTemplateVersion.create(template_name, ami) do |lt|
              puts "Autoscaling: Created Launch Template Version: #{lt.aws_counterpart.version_description} from region #{region} in ASG #{asg}"

              asg_launch_templates[region][asg] = lt.aws_counterpart.version_description

              lt.set_as_default!
            end
          else
            Capistrano::Asg::LaunchConfiguration.create(ami, fetch("#{region}_#{asg}".to_sym, {})) do |lc|
              puts "Autoscaling: Created Launch Configuration: #{lc.aws_counterpart.name} from region #{region} in ASG #{asg}"

              asg_launch_config[region][asg] = lc.aws_counterpart.name

              lc.attach_to_autoscale_group!
            end
          end
        end
      end
    end

    set :asg_launch_templates, asg_launch_templates
    set :asg_launch_config, asg_launch_config
    set :asg_ami_id, asg_ami_id
  end
end
