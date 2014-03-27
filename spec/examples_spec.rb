require 'rspec/given'
require 'cfnpp/transform'

def input_file(name)
    return "spec/resources/stack/#{name}.yml"
end

def expect_output(name)
    return JSON.load(File.open("spec/resources/expect/#{name}.json").read)
end

describe "functional tests" do
  describe "simple inline template" do
    Given(:name) { "simple-inline-template" }
    When(:output) { CfnPP::Transform.load_file(input_file(name)) }
    Then { output.data.should eq(expect_output(name)) }
  end
  describe "simple inline nested stack" do
    Given(:name) { "simple-inline-nested-stack" }
    When(:output) { CfnPP::Transform.load_file(input_file(name)) }
    Then { output.data.should eq(expect_output(name)) }
    And  { output.substacks.length == 1 }
    And  { output.substacks[0].data.should eq (expect_output("#{name}-nest1")) }
  end
end

