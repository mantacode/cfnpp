require 'digest'

module CfnPP
  class TemplateResult
    attr_accessor :substacks
    attr_accessor :data

    def initialize(name, data, stack_url_base="", substacks = [])
      @base_name = name
      @data = data
      @stack_url_base = stack_url_base
      @substacks = substacks
    end

    def url
      return "#{@stack_url_base}/#{name}/template.json"
    end   

    def name
      return "#{@base_name}-#{checksum}"
    end

    def checksum
      return Digest::SHA256.hexdigest(@data.to_json)
    end
  end
end

