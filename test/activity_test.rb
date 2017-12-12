require "test_helper"

class ActivityTest < Minitest::Spec
  class A
    def self.call((options, flow_options), *)
      options[:A] = 1

      [ options[:a_return], options, flow_options ]
    end
  end
  class B < Activity::End
    def call((options, flow_options), *)
      options[:B] = 1
      super
    end
  end
  class C
    def self.call((options, flow_options), *)
      options[:C] = 1

      [ options[:c_return], options, flow_options ]
    end
  end
  class D
    def self.call((options, flow_options), *)
      [ options, flow_options ]
    end
  end
  class G
    def self.call((options, flow_options), *)
      options[:G] = 1

      [ options[:g_return], options, flow_options ]
    end
  end
  class I
    def self.call((options, flow_options), *)
      options[:I] = 1

      [ options[:i_return], options, flow_options ]
    end
  end
  class J
    def self.call((options, flow_options), *)
      options[:J] = 1

      [ Trailblazer::Activity::Right, options, flow_options ]
    end
  end
  class K
    def self.call((options, flow_options), *)
      options[:K] = 1

      [ Trailblazer::Activity::Right, options, flow_options ]
    end
  end
  class L
    def self.call((options, flow_options), *)
      options[:L] = 1

      [ Trailblazer::Activity::Right, options, flow_options ]
    end
  end

  Left = Trailblazer::Activity::Left
  Right = Trailblazer::Activity::Right

  it "empty Activity" do
    activity = Activity.build do
    end

    # puts Cct(activity.instance_variable_get(:@process))
    Cct(activity.instance_variable_get(:@process)).must_equal %{
#<Start:default/nil>
 {Trailblazer::Activity::Right} => #<End:success/:success>
#<End:success/:success>
}

    Outputs(activity.outputs).must_equal %{success=> (#<Trailblazer::Activity::End:>, success)}

    options = { id: 1 }

    signal, args, circuit_options = activity.( [options, {}], {} )

    signal.must_equal activity.outputs[:success].signal
    args.inspect.must_equal %{[{:id=>1}, {}]}
    circuit_options.must_be_nil
  end

  let(:activity) do
    activity = Activity.build do
      # circular
      task A, id: "inquiry_create", Output(Left, :failure) => Path() do
        task B.new(:resume_for_correct, semantic: :resume_1), id: "resume_for_correct", type: :End
        task C, id: "suspend_for_correct", Output(:success) => "inquiry_create"
      end

      task G, id: "receive_process_id"
      task I, id: :process_result, Output(Left, :failure) => Path(end_semantic: :invalid_result) do
        task J, id: "report_invalid_result"
        task K
      end

      task L, id: :notify_clerk
    end
  end

  it do
    Outputs(activity.outputs).must_equal %{resume_1=> (#<ActivityTest::B:>, resume_1)
success=> (#<Trailblazer::Activity::End:>, success)
invalid_result=> (#<Trailblazer::Activity::End:>, invalid_result)}

    Cct(activity.instance_variable_get(:@process)).must_equal %{
#<Start:default/nil>
 {Trailblazer::Activity::Right} => ActivityTest::A
ActivityTest::A
 {Trailblazer::Activity::Left} => #<ActivityTest::B:resume_for_correct/:resume_1>
 {Trailblazer::Activity::Right} => ActivityTest::G
#<ActivityTest::B:resume_for_correct/:resume_1>

ActivityTest::C
 {Trailblazer::Activity::Right} => ActivityTest::A
ActivityTest::G
 {Trailblazer::Activity::Right} => ActivityTest::I
ActivityTest::I
 {Trailblazer::Activity::Left} => ActivityTest::J
 {Trailblazer::Activity::Right} => ActivityTest::L
ActivityTest::J
 {Trailblazer::Activity::Right} => ActivityTest::K
ActivityTest::K
 {Trailblazer::Activity::Right} => #<End:track_0./:invalid_result>
ActivityTest::L
 {Trailblazer::Activity::Right} => #<End:success/:success>
#<End:success/:success>

#<End:track_0./:success>

#<End:track_0./:invalid_result>
}


    Ends(activity.instance_variable_get(:@process)).must_equal %{[#<ActivityTest::B:resume_for_correct/:resume_1>,#<End:success/:success>,#<End:track_0./:invalid_result>]}

    # A -> B -> End.suspend
    options, flow_options, circuit_options = {id: 1, a_return: Activity::Left, b_return: Activity::Right }, {}, {}
    # ::call
    signal, (options, _) = activity.( [options, flow_options], circuit_options )

    signal.must_equal activity.outputs[:resume_1].signal
    options.inspect.must_equal %{{:id=>1, :a_return=>Trailblazer::Activity::Left, :b_return=>Trailblazer::Activity::Right, :A=>1, :B=>1}}

    #---
    #- start from C, stop in B
    options = { c_return: Activity::Right, a_return: Activity::Left }
    signal, (options, _) = activity.( [options, flow_options], task: C )

    signal.must_equal activity.outputs[:resume_1].signal
    options.inspect.must_equal %{{:c_return=>Trailblazer::Activity::Right, :a_return=>Trailblazer::Activity::Left, :C=>1, :A=>1, :B=>1}}

    #---
    #- start from C, via G>I>L
    options = { c_return: Activity::Right, a_return: Activity::Right, g_return: Activity::Right, i_return: Activity::Right }
    signal, (options, _) = activity.( [options, flow_options], task: C )

    signal.must_equal activity.outputs[:success].signal
    options.inspect.must_equal %{{:c_return=>Trailblazer::Activity::Right, :a_return=>Trailblazer::Activity::Right, :g_return=>Trailblazer::Activity::Right, :i_return=>Trailblazer::Activity::Right, :C=>1, :A=>1, :G=>1, :I=>1, :L=>1}}

    #---
    #- start from C, via G>I>J>K
    options = { c_return: Activity::Right, a_return: Activity::Right, g_return: Activity::Right, i_return: Activity::Left }
    signal, (options, _) = activity.( [options, flow_options], task: C )

    signal.must_equal activity.outputs[:invalid_result].signal
    options.inspect.must_equal %{{:c_return=>Trailblazer::Activity::Right, :a_return=>Trailblazer::Activity::Right, :g_return=>Trailblazer::Activity::Right, :i_return=>Trailblazer::Activity::Left, :C=>1, :A=>1, :G=>1, :I=>1, :J=>1, :K=>1}}

    # activity.draft #=> mergeable, inheritance.
  end

  it "can start with any task" do
    signal, (options, _) = activity.( [{}], task: L )

    signal.must_equal activity.outputs[:success].signal
    options.inspect.must_equal %{{:L=>1}}
  end

  describe "inheritance" do
    it "creates a fresh Activity" do
      activity = Class.new(Activity) do
        task A
        task B
      end

      Cct(activity.instance_variable_get(:@process)).must_equal %{
#<Start:default/nil>
 {Trailblazer::Activity::Right} => ActivityTest::A
ActivityTest::A
 {Trailblazer::Activity::Right} => ActivityTest::B
ActivityTest::B
 {Trailblazer::Activity::Right} => #<End:success/:success>
#<End:success/:success>
}

      subactivity = Class.new(activity) do
        task C
      end

      Cct(subactivity.instance_variable_get(:@process)).must_equal %{
#<Start:default/nil>
 {Trailblazer::Activity::Right} => ActivityTest::A
ActivityTest::A
 {Trailblazer::Activity::Right} => ActivityTest::B
ActivityTest::B
 {Trailblazer::Activity::Right} => ActivityTest::C
ActivityTest::C
 {Trailblazer::Activity::Right} => #<End:success/:success>
#<End:success/:success>
}
    end
  end
end

