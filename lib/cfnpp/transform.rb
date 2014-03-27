require 'json'
require 'yaml'
require_relative 'replacer'
require_relative 'templateresult'
require 'set'
require 'erb'

# CfnPP is a module with various methods to make working with CloudFormation
# templates easier. Particularly, it has facilities for writing templates in
# YAML, with added features for modularizing templates, easily writing
# user-data blocks, etc.
module CfnPP
  # This class has methods to read in cloudformation templates in YAML
  # format with some Manta-specific extensions to make things easier.
  class Transform
    # returns a ruby hash, from a file at +path+
    #
    # This is the easiest way to load things. It takes care of
    # setting reasonable file base for includes, etc., and gives
    # you back a hash ready for use.
    def self.load_file(path, opts = {}, name = "main", stack_url_base="http://example.com")
      return self.load_yaml(File.read(path), path, opts, name)
    end

    # returns a ruby hash, from unparsed YAML input text.
    #
    def self.load_yaml(yaml_txt, filebase=".", opts={}, name = "main", stack_url_base="http://example.com")
      h = YAML::load(yaml_txt)
      return self.new(h, filebase, opts, name).as_template_result
    end

    # CfnPP::Transform is initialized with a hash and an optional file base
    # parameter. The file base will default to ".", which may or may
    # not be what you want.
    def initialize(in_hash, filebase=".", opts={}, name="main", stack_url_base="http://example.com")
      @name = name
      @opts = opts
      @filebase = filebase
      @stack_url_base = stack_url_base
      @in_hash = { :root => in_hash }
      @tops = self.class.stdtops()
      trans_hash(@in_hash)
      @in_hash = @in_hash[:root]
      @substacks = grab_stacks(@in_hash)
      lift
      @in_hash = apply_opts(@in_hash, opts)
      prune(@in_hash)
    end

    # Return the parsed, processed CfnPP YAML file as a ruby hash
    def as_hash
      return @in_hash
    end

    def as_template_result
      return CfnPP::TemplateResult.new(@name, @in_hash, @stack_url_base, @substacks)
    end

    private

    # which keys always get lifted to the top
    def self.stdtops
      return Set.new ["Parameters", "Mappings", "Resources", "Outputs", "Conditions"]
    end

    # classic recursion!
    def apply_opts(thing, opts)
      if thing.is_a? Hash
        if thing.has_key? 'CfnPPRef'
          if not opts.has_key? thing['CfnPPRef']
            raise "missing value for '#{thing['CfnPPRef']}'"
          end
          return "#{opts[thing['CfnPPRef']] || ''}"
        else
          r = {}
          thing.each { |k,v| r[k] = apply_opts(v, opts) }
          return r
        end
      elsif thing.is_a? Array
        return thing.collect { |t| apply_opts(t, opts) }
      else
        return thing
      end
    end

    # give the contents of a named file; handle any directory weirdness
    # here
    def read_ext(name)
      return File.read File.join(File.dirname(@filebase), name)
    end

    # how the results of a CfnPPTemplate are put back into the tree
    def sub_merge(h, key, v)
      if v.is_a? Hash then
        h[key].merge! v
      else
        h[key] = v
      end
    end

    # sniff the type of filter based on the string contents
    def auto_filter(txt)
      if txt =~ /^---/
        return "erb-yaml"
      else
        return "replacer"
      end
    end

    # given the multiple ways a template can be specified, create
    # a single predictable Hash to be used elsewhere
    def norm_tmplspec(v)
      if v.is_a? String
        rec = {
          "filter" => "",
          "txt"    => "",
          "vars"   => {},
        }
        if File.exists? File.join(File.dirname(@filebase), v)
          rec["txt"] = read_ext v
        else
          rec["txt"] = v
        end
        rec["filter"] = auto_filter(rec["txt"])
        return rec
      elsif v.is_a? Hash
        if v["path"]
          v["txt"] = read_ext v["path"]
        end
        if not v.has_key? "filter"
          v["filter"] = auto_filter(v["txt"])
        end
        return v
      end
    end

    # Apply the given filter to the text content, with given
    # vars.
    # the overloading of Replacer here is super weird and
    # ugly. Sorry. Will fix... soon?
    def proc_tmplspec(rec)
      replacer = Replacer.new(rec["txt"], rec["vars"], @opts)
      if rec["filter"] == 'replacer'
        return replacer.process
      elsif rec["filter"] == 'erb-yaml'
        res = replacer.process_basic
        #puts "#{res}"
        #ERB.new rec["txt"]
        return YAML::load(res)
      end
    end

    # trans/trans_hash/trans_array walk the tree
    def trans(e)
      if e.is_a? Hash
        trans_hash(e)
      end
      if e.is_a? Array
        trans_array(e)
      end
    end

    def trans_hash(h)
      h.keys.each do |key|
        if (h[key].is_a? Hash) and (h[key].has_key? "CfnPPTemplate")
          rec = norm_tmplspec h[key]["CfnPPTemplate"]
          v = proc_tmplspec(rec)
          trans(v)
          sub_merge(h, key, v)
        elsif (h[key].is_a? Hash) and (h[key].has_key? "CfnPPStack")
          rec = h[key]["CfnPPStack"]
          if rec.has_key? "inline"
            inline = rec["inline"]
            name = rec["name"]
            rec.delete("inline")
            rec["result"] = self.class.new(inline, @filebase, @opts, name, @stack_url_base).as_template_result
            rec["Resources"] = {} if not rec["Resources"]
            rec["Resources"][name] = {
              "Type" => "AWS::CloudFormation::Stack",
              "Properties" => {
                "TemplateURL" => rec["result"].url,
                "TimeoutInMinutes" => 60,
              }
            }
          end
        else
          trans(h[key])
        end
      end
    end

    def trans_array(a)
      a.each do |e|
        trans(e)
      end
    end

    # recursively remove any keys we want cleaned up. due to lifting they
    # can leave junk laying around
    def prune(h)
      prunes = ["CfnPPTemplate", "MantaTemplateInclude", "MantaTemplate", "MantaInclude", "CfnPPSection", "CfnPPStack"]
      if h.is_a? Hash then
        h.keys.each do |k|
          if prunes.include? k then
            h.delete(k)
          else
            prune(h[k])
          end
        end
      elsif h.is_a? Array then
        h.each { |e| prune(e) }
      end
    end

    # return all of the embedded stack objects. super, super
    # ugly
    def grab_stacks(h)
      stacks = []
      if h.is_a? Hash
        h.keys.each do |k|
          if k == "CfnPPStack" and h[k].has_key? "result"
            stacks.push(h[k]["result"])
          else
            stacks.concat(grab_stacks(h[k]))
          end
        end
      end
      return stacks
    end

    # given some defined top keys, find them everywhere, cut them out,
    # and put them back in at the top level. Weirdly fiddly code.
    def lift

      def lifter(h, tops, store)
        h.keys.each do |key|
          if h[key].is_a? Hash
            lifter(h[key], tops, store)
          elsif h[key].is_a? Array
            h[key].each do |e|
              if e.is_a? Hash
                lifter(e, tops, store)
              end
            end
          end
          if tops.include? key
            if (not store[key])
              store[key] = []
            end
            store[key].push h.delete(key)
          end
        end
      end

      h = @in_hash
      store = {}
      lifter(h, @tops, store)
      store.keys.each do |k|
        n = {}
        store[k].each do |se|
          n = n.merge se
        end
        h[k] = n
      end
    end
  end
end
