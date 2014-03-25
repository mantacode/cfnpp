module CfnPP
  class Uploader
    def initialize(bucketname, stackname)
      @bucket = AWS::S3.new.buckets[bucketname]
      @stackname = stackname
      @timestamp = new_timestamp
      @s3_path = "stacks/#{@stack_name}/#{@timestamp}"
      @cfn = AWS::CloudFormation.new
    end

    def new_timestamp
      return Time.now.utc.strftime("%Y-%m-%dT%H.%M.%S.%LZ")
    end

    def upload_template(template_result, opts)
      obj = @bucket.objects.create("#{s3_path}/#{template_result.name}./template.json", template_result.data.to_json)
      url = obj.public_url
      status = cfn.validate_template(url)
      if not template_status.has_key? :code
        tp = template_status.fetch(:parameters, [])
        upload_params(template_result.name, tp)
      end
      return {
        :url    => url,
        :status => status
      }
    end

    def upload_parameters(name, params)
      opts_parameters = {}
      params.each do |param|
        key = param[:parameter_key]
        opts_parameters[key] = opts[key] if opts.has_key? key
      end
      return @bucket.objects.create("#{@s3_path}/#{name}/parameters.yml", opts_parameters.to_yaml)
    end

  end
end
