require 'aws-sdk'
require 'json'
require 'yaml'

module CfnPP
  class Uploader
    def initialize(bucketname, stackname)
      @bucket = AWS::S3.new.buckets[bucketname]
      @stackname = stackname
      @timestamp = new_timestamp
      @s3_path = "testing/stacks/#{@stackname}/#{@timestamp}"
      @cfn = AWS::CloudFormation.new
    end

    def new_timestamp
      return Time.now.utc.strftime("%Y-%m-%dT%H.%M.%S.%LZ")
    end

    def s3_path
      return @s3_path
    end

    def upload_template(template_result, opts)
      r = { :url => nil, :error => nil, :validation_status => nil }

      already_updated = ploy_update_guard(template_result.name, opts)
      if already_updated
        r[:err] = 'already_updated'
        r[:prev_opts] = already_updated
        return r
      end

      obj = @bucket.objects.create("#{@s3_path}/#{template_result.name}/template.json", template_result.data.to_json)
      r[:url] = obj.public_url
      r[:validation_status] = @cfn.validate_template(r[:url])
      if r[:validation_status].has_key? :code #error condition
        r[:error] = 'validation_error'
      else
        tp = r[:validation_status].fetch(:parameters, [])
        r[:opts_parameters] = opts_parameters(tp, opts)
        upload_parameters(template_result.name, r[:opts_parameters])
      end
      return r
    end

    def opts_parameters(params, opts)
      opts_parameters = {}
      params.each do |param|
        key = param[:parameter_key]
        opts_parameters[key] = opts[key] if opts.has_key? key
      end
      return opts_parameters
    end

    def upload_parameters(name, opts_parameters)
      return @bucket.objects.create("#{@s3_path}/#{name}/parameters.yml", opts_parameters.to_yaml)
    end

    def ploy_update_guard(name, opts)
      if opts['TemplateSource'] == 'ploy'
        return find_previous_ploy_update(cfn_bucket, opts)
      end
      return nil
    end

    def find_previous_ploy_update(name, opts)
      stack_name = opts['StackName']
      launch_list = @bucket.objects.with_prefix("stacks/#{stack_name}").sort do |a,b|
        a.key <=> b.key
      end
      launch_list.each do |o|
        if o.key =~ /\/parameters.yml$/
          prev_opts = YAML::load(o.read)
          if prev_opts['TemplateSource'] == opts['TemplateSource']
            if prev_opts['TemplateGitRevision'] == opts['TemplateGitRevision']
              return prev_opts
            end
          end
        end
      end
      return nil
    end

  end
end
