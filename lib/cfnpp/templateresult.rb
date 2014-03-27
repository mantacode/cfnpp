require 'digest'

module CfnPP
  class TemplateResult
    attr_accessor :substacks
    attr_accessor :data

    def initialize(name, data, substacks = [])
      @base_name = name
      @data = data
      @substacks = substacks
    end
    
    def name
      return "#{@base_name}-#{checksum}"
    end

    def checksum
      return Digest::SHA256.hexdigest(@data.to_json)
    end
  end
end

