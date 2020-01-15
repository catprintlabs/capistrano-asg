# frozen_string_literal: true

module Capistrano
  module Asg
    class LaunchTemplateVersion < AWSResource
      attr_reader :region_config

      def self.create(name, ami, region_config = {}, &_block)
        version = new(name, region_config)

        version.save(ami)

        yield version
      end

      def initialize(name, region_config = {})
        @name = name
        @region_config = region_config
      end

      def save(ami)
        info "Creating an EC2 Launch Template Version for AMI: #{ami.aws_counterpart.id}"

        with_retry do
          # Create the new version
          @aws_counterpart = ec2_client.create_launch_template_version(
            launch_template_name: @name,
            source_version:       launch_template.default_version_number.to_s,
            version_description: description,
            launch_template_data: {
              image_id: ami.aws_counterpart.id
            }.merge(region_config)
          ).launch_template_version
        end
      end

      def set_as_default!
        info "Setting Launch Template Version #{aws_counterpart.version_description} as default for #{@name}"

        ec2_client.modify_launch_template(
          launch_template_name: @name,
          default_version:      aws_counterpart.version_number.to_s
        )
      end

      private

      def description
        timestamp region_config.fetch(:aws_lc_name_prefix, "cap-asg-#{environment}-#{autoscaling_group_name}-lt")
      end

      def launch_template
        @launch_template ||= ec2_client.describe_launch_templates(
          launch_template_names: [@name]
        ).launch_templates&.first
      end
    end
  end
end
