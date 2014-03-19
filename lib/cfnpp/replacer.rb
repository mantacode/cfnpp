require 'json'
require 'yaml'
require 'erb'
require 'pp'

module CfnPP
	# Implements logic for having textual templates that get turned
	# into CloudFormation Fn::Join invocations. This makes userdata scripts
	# and other things much easier to read.
	#
	# The templates are ERB syntax, with three functions available for
	# inserting CloudFormation references: +cfn_raw+, +cfn_ref+ and +cfn_getatt+.
	#
	# == Example Template
	#     #!/bin/bash
	#     yum update -y aws-cfn-bootstrap
	#     /opt/aws/bin/cfn-init -s <%= cfn_ref("AWS::StackId") %> -r LaunchConfig --region <%= cfn_ref("AWS::Region") %>
	#     /opt/aws/bin/cfn-signal -e $? <%= cfn_ref("WaitHandle") %>
	#     # Setup correct file ownership
	#     chown -R apache:apache /var/www/html/wordpress
	#
	# == Example use of CfnPP::Replacer
	#     template_text = "..."
	#     cfn_hash = CfnReplacer.new.process(template_text)
	class Replacer
		# Turns input text into a Hash appropriate for inserting into a
		# CloudFormation structure.
    def initialize(text, vars = {}, opts = {})
      @text = text
      @r_vars = vars
      @opts = opts
    end

		def process()
			tmpl = ERB.new @text
			joinparts = []
			tmpl.result(self.get_binding).split('@@@').each do |chunk|
				if chunk.match(/^\{/)
					chunk = JSON.parse(chunk)
				end
				joinparts.push(chunk)
			end
			return { "Fn::Join" => [ '', joinparts ] }
		end

    def process_basic()
      tmpl = ERB.new @text
      return tmpl.result(self.get_binding)
    end

    def cfn_render(path)
			txt = File.read File.join(File.dirname('.'), path)
			tmpl = ERB.new txt
			return tmpl.result(self.get_binding)
    end

    # for local refs (instead of cfn_ref)
    def cfn_cfnpp_ref(s)
      return @opts[s]
    end

		# called in the template to include any arbitrary CloudFormation code.
		def cfn_raw(h)
			txt = JSON.dump h
			return "@@@#{txt}@@@"
		end

		# shortcut for inserting a cfn "Ref"; just pass the "Ref" value
		def cfn_ref(s)
			return cfn_raw({ "Ref" => s })
		end

		# shortcut for inserting a cfn "Fn::GetAtt"; just pass a two element
		# array of the key and value to get
		def cfn_getatt(k,v)
			return cfn_raw({ "Fn::GetAtt" => [k, v]})
		end

		def get_binding
			binding
		end
	end
end
