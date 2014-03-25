module CfnPP
  class TemplateResult
    attr_accessor :substacks
    attr_accessor :data

    def initialize(stackname, data, substacks = [])
      @stackname = stackname
      @data = data
      @substacks = substacks
    end
    
    def name
      return 'static-test-name'
    end
  end
end

