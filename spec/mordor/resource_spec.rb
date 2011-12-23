require File.join(File.dirname(__FILE__), '..', '/spec_helper.rb')

describe "with respect to resources" do
  before :each do
    class TestResource
      include Mordor::Resource

      attribute :first, :index => true
      attribute :second
      attribute :third, :finder_method => :find_by_third_attribute

      # Put this in here again to ensure the original method is still here
      class_eval do
        def self.ensure_indices
          collection.ensure_index( indices.map{|index| [index.to_s, Mongo::DESCENDING]} ) if indices.any?
        end

      end
    end
  end

  it "should create accessor methods for all attributes" do
    ["first", "first=", "second", "second="].each{ |v| TestResource.public_instance_methods.should include(v) }
  end

  it "should create class level finder methods for all attributes" do
    ["find_by_first", "find_by_second"].each do |finder_method|
      TestResource.methods.should include(finder_method)
    end
  end

  it "should create finder methods with the supplied finder method name" do
    TestResource.methods.should include "find_by_third_attribute"
  end

  it "should ensure indices when the option :index => true is given" do
    TestResource.indices.should include :first
  end

  it "should call ensure_index on the collection for each index when a query is performed" do
    TestResource.class_eval do
      def self.ensure_count
        @count ||= 0
      end

      def self.ensure_count=(val)
        @count = val
      end

      private
      def self.ensure_indices
        self.ensure_count = self.ensure_count + 1
      end
    end
    TestResource.create({:first => 'first', :second => 'second', :third => 'third'})
    TestResource.all()
    TestResource.ensure_count.should == 1
  end

  context "with respect to replacing params" do
    before :each do
      clean_sheet
    end

    it "should correctly substitute non-alphanumeric characters in keys with underscores" do
      options = {
        "o*p#t>i_o@n)s" => "test"
      }
      result = TestResource.new.replace_params(options)
      result.keys.first.should eql "o_p_t_i_o_n_s"
    end

    it "should correctly replace Date and DateTimes" do
      options = {
        "option" => Date.today,
        "another" => DateTime.now
      }
      result = TestResource.new.replace_params(options)
      result.each do |k, v|
        v.should be_a Time
      end
    end

    it "should correctly replace BigDecimals" do
      options = {
        "option" => BigDecimal.new("1.00")
      }
      result = TestResource.new.replace_params(options)
      result.each do |k,v|
        v.should be_a Float
      end
    end

    it "should correctly respond to to_hash" do
      resource = TestResource.new({:first => "first", :second => "second", :third => "third"})
      hash = resource.to_hash
      hash.size.should     == 3
      hash[:first].should  == "first"
      hash[:second].should == "second"
      hash[:third].should  == "third"
    end
  end

  context "with respect to creating" do
    before :each do
      clean_sheet
      @resource = TestResource.create({:first => "first", :second => "second", :third => "third"})
    end

    it "should be possible to create a resource" do
      @resource.should be_saved
    end

    it "should be possible to retrieve created resources" do
      res = TestResource.get(@resource._id)
      res.should_not be_nil
      res.first.should eql @resource.first
      res.second.should eql @resource.second
      res.third.should eql @resource.third
      res._id.should eql @resource._id
    end
  end

  context "with respect to saving and retrieving" do
    before :each do
      clean_sheet
    end

    it "should correctly save resources" do
      resource = TestResource.new({:first => "first", :second => "second"})
      resource.save.should be_true
      resource._id.should_not be_nil
      resource.collection.count.should == 1
      resource.collection.find_one['_id'].should == resource._id
    end

    it "should correctly update resources" do
      resource = TestResource.new({:first => "first", :second => "second"})
      resource.save.should be_true
      resource._id.should_not be_nil

      original_id = resource._id

      resource.collection.count.should == 1
      resource.collection.find_one['_id'].should == resource._id

      resource.first = "third"
      resource.save.should be_true
      resource._id.should == original_id
      resource.collection.find_one['first'].should == resource.first
    end

    it "should be able to find resources by their ids" do
      resource = TestResource.new({:first => "first", :second => "second"})
      resource.save.should be_true
      res = TestResource.find_by_id(resource._id)
      res._id.should    == resource._id
      res.first.should  == resource.first
      res.second.should == resource.second
    end

    it "should be able to find resources by their ids as strings" do
      resource = TestResource.new({:first => "first", :second => "second"})
      resource.save.should be_true
      res = TestResource.find_by_id(resource._id.to_s)
      res._id.should    == resource._id
      res.first.should  == resource.first
      res.second.should == resource.second
    end

    it "should be possible to find resources using queries" do
      resource = TestResource.new({:first => "first", :second => "second"})
      resource.save.should be_true

      resource2 = TestResource.new({:first => "first", :second => "2nd"})
      resource2.save.should be_true

      collection = TestResource.find({:first => "first"})
      collection.should_not be_nil
      collection.size.should == 2

      collection = TestResource.find({:second => "2nd"})
      collection.should_not be_nil
      collection.size.should == 1
    end

    it "should be possible to query with a limit" do
      resource = TestResource.new({:first => "first", :second => "second"})
      resource.save.should be_true

      resource2 = TestResource.new({:first => "first", :second => "2nd"})
      resource2.save.should be_true

      collection = TestResource.find({:first => "first"}, :limit => 1)
      collection.should_not be_nil
      collection.size.should == 1
    end

    it "should be possible to retrieve all resources" do
      TestResource.all.should_not be_nil
      TestResource.all.size.should == 0

      resource = TestResource.new({:first => "first", :second => "second"})
      resource.save.should be_true

      resource2 = TestResource.new({:first => "first", :second => "second"})
      resource2.save.should be_true

      collection = TestResource.all
      collection.should_not be_nil
      collection.size.should == 2
    end

    it "should be possible to limit the number of returned resources" do
      TestResource.all.should_not be_nil
      TestResource.all.size.should == 0

      resource = TestResource.new({:first => "first", :second => "second"})
      resource.save.should be_true

      resource2 = TestResource.new({:first => "first", :second => "second"})
      resource2.save.should be_true

      collection = TestResource.all(:limit => 1)
      collection.should_not be_nil
      collection.size.should == 1
    end
  end

  context "with respect to retrieving by day" do
    class TestTimedResource
      include Mordor::Resource

      attribute :first
      attribute :at
    end

    before :each do
      clean_sheet
    end

    it "should be possible to retrieve a Resource by day" do
      TestTimedResource.create({:first => "hallo", :at => DateTime.civil(2011, 11, 11, 11, 11)})

      col = TestTimedResource.find_by_day(DateTime.civil(2011,11,11))
      col.size.should == 1
      col.first.first.should eql "hallo"
    end

    it "should not retrieve resources from other days" do
      TestTimedResource.create({:first => "hallo", :at => DateTime.civil(2011, 11, 11, 11, 11)})

      col = TestTimedResource.find_by_day(DateTime.civil(2011,11,10))
      col.size.should == 0
    end
 end

  context "with respect to collections" do
    it "should correctly return a collection name" do
      TestResource.collection_name.should == "testresources"
    end

    it "should correctly create a connection" do
      TestResource.connection.should_not be_nil
    end
  end

  context "with respect to not finding something" do
    it "should just return an empty collection when a collection query doesn't return results" do
      col = TestResource.find_by_day(DateTime.civil(2011, 11, 8))
      col.size.should == 0
    end

    it "should return nil when an non existing id is queried" do
      clean_sheet
      resource = TestResource.find_by_id('4eb8f3570e02e10cce000002')
      resource.should be_nil
    end
  end


end
