module CfnPP
  class TemplateResult
    def initialize(stackname, data)
      @stackname = stackname
      @data = data
    end
    
    def data
      return @data
    end

    def filename
    end
  end
end

