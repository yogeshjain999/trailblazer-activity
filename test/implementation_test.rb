require "test_helper"

class GeneratedTest < Minitest::Spec
  def MyMacro(*args)
    {}
  end
# TODO: test with more than one End
# TODO: test with different Start, not automatic
# TODO: allow passing in your own End instanc  es (not urgent)


  # generated by the editor or a specific DSL.
  let(:intermediate) do
    Inter.new(
      {
        Inter::TaskRef(:a) => [Inter::Out(:success, :b)],
        Inter::TaskRef(:b) => [Inter::Out(:success, "End.success")],
        Inter::TaskRef("End.success", stop_event: true) => [Inter::Out(:success, nil)], # this is how the End semantic is defined.
      },
      [
        Inter::TaskRef("End.success"),
        # Inter::TaskRef("End.failure"),
      ],
      [Inter::TaskRef(:a)] # start
    )
  end

  it "compiles {Schema} from intermediate and implementation, with one end" do
    _implementing = implementing
    _intermediate = intermediate

    # DISCUSS: basically, this is a thin DSL that calls Intermediate.(;)
    # you use this with a editor.


    impl = Class.new(Trailblazer::Activity::Implementation) do
      implement _intermediate,
        a: _implementing.method(:a),    # TODO: :method
        b: _implementing.method(:b)#,    # TODO: :method
      # a: {task: .., outputs: .., }
        # b: MyMacro(:User, :find_by),
        # "End.success" => _implementing::Failure#, [Activity::Output(implementing::Failure, :failure)]),
    end

    assert_process_for impl, :success, %{
<*#<Method: #<Module:0x>.a>>
 {Trailblazer::Activity::Right} => <*#<Method: #<Module:0x>.b>>
<*#<Method: #<Module:0x>.b>>
 {Trailblazer::Activity::Right} => #<End/:success>
#<End/:success>
}


    signal, (ctx, _) = impl.([seq: []])

    signal.inspect.must_equal %{#<Trailblazer::Activity::End semantic=:success>}
    ctx.inspect.must_equal %{{:seq=>[:a, :b]}}
    # merge! ==> like inheritance without inheriting methods.

    # Manu
    # merge!(MyActivity, a: "different_method")

  end

  describe ":method" do
    let(:nested_implementation) do

      _intermediate = intermediate

      impl = Class.new(Trailblazer::Activity::Implementation) do
        implement _intermediate,
          a: :a,
          b: :b

        def a(ctx, seq:, **)
          seq << :a
        end

        def b(ctx, seq:, **)
          seq << :b
        end
      end

    end

    it "allows :instance_method tasks" do
      assert_process_for nested_implementation, :success, %{
<*a>
 {Trailblazer::Activity::Right} => <*b>
<*b>
 {Trailblazer::Activity::Right} => #<End/:success>
#<End/:success>
}

      signal, (ctx, _) = nested_implementation.([seq: []])

      signal.inspect.must_equal %{#<Trailblazer::Activity::End semantic=:success>}
      ctx.inspect.must_equal %{{:seq=>[:a, :b]}}
    end

    it "allows nesting" do
      nester = Inter.new(
        {
          Inter::TaskRef(:a) => [Inter::Out(:success, :b)],
          Inter::TaskRef(:b) => [Inter::Out(:success, :c)],
          Inter::TaskRef(:c) => [Inter::Out(:success, "End.success")],
          Inter::TaskRef("End.success", stop_event: true) => [Inter::Out(:success, nil)], # this is how the End semantic is defined.
        },
        [
          Inter::TaskRef("End.success"),
          # Inter::TaskRef("End.failure"),
        ],
        [Inter::TaskRef(:a)] # start
      )

      _nested_implementation = nested_implementation

      impl = Class.new(Trailblazer::Activity::Implementation) do
        implement nester,
          a: :a,
          b: _nested_implementation,
          c: :c

        def a(ctx, seq:, **)
          seq << :A
        end

        def c(ctx, seq:, **)
          seq << :C
        end
      end

      assert_process_for impl, :success, %{
<*a>
 {Trailblazer::Activity::Right} => <*#<Class:0x>>
<*#<Class:0x>>
 {Trailblazer::Activity::Right} => <*c>
<*c>
 {Trailblazer::Activity::Right} => #<End/:success>
#<End/:success>
}

      signal, (ctx, _) = impl.([seq: []])

      signal.inspect.must_equal %{#<Trailblazer::Activity::End semantic=:success>}
      ctx.inspect.must_equal %{{:seq=>[:A, :a, :b, :C]}}
    end
  end

  it "allows Macro()" do
    _implementing = implementing
    _intermediate = intermediate

    merge = [
      [TaskWrap::Pipeline.method(:insert_before), "task_wrap.call_task", ["user.add_1", method(:add_1)]],
      [TaskWrap::Pipeline.method(:insert_after),  "task_wrap.call_task", ["user.add_2", method(:add_2)]],
    ]

# add taskWrap extensions with this macro.
    MyMacro = ->(*) { {
      id: "MyMacro_id", # ignored
      outputs: {success: Activity::Output(Activity::Right, :success)},
      task: t= Activity::TaskBuilder.Binary(_implementing.method(:f)),
      extensions: [
        # TaskWrap::Extension.new(task: t, merge: TaskWrap.method(:initial_wrap_static)),
        TaskWrap::Extension(task: t, merge: merge)
      ]
    } }

    # DISCUSS: basically, this is a thin DSL that calls Intermediate.(;)
    # you use this with a editor.


    impl = Class.new(Trailblazer::Activity::Implementation) do
      implement _intermediate,
        start: false,
        a: _implementing.method(:a),    # TODO: :method
        b: MyMacro.(:User, :find_by)
        # "End.success" => _implementing::Failure#, [Activity::Output(implementing::Failure, :failure)]),
    end

    assert_process_for impl, :success, %{
<*#<Method: #<Module:0x>.a>>
 {Trailblazer::Activity::Right} => <*#<Method: #<Module:0x>.f>>
<*#<Method: #<Module:0x>.f>>
 {Trailblazer::Activity::Right} => #<End/:success>
#<End/:success>
}

    signal, (ctx, _) = Activity::TaskWrap.invoke(impl, [seq: []])

    signal.inspect.must_equal %{#<Trailblazer::Activity::End semantic=:success>}
    ctx.inspect.must_equal %{{:seq=>[:a, 1, :f, 2]}}
  end

  it "adds a {Start.default} when {start: false} not set" do
    _implementing = implementing

    _intermediate = Inter.new(
      {
        Inter::TaskRef("Start.default") => [Inter::Out(:success, :a)],
        Inter::TaskRef(:a) => [Inter::Out(:success, "End.success")],
        Inter::TaskRef("End.success", stop_event: true) => [Inter::Out(:success, nil)], # this is how the End semantic is defined.
      },
      [
        Inter::TaskRef("End.success"),
      ],
      [Inter::TaskRef("Start.default")] # start
    )

    impl = Class.new(Trailblazer::Activity::Implementation) do
      implement _intermediate,
        a: _implementing.method(:a)
    end

    assert_process_for impl, :success, %{
#<Start/:success>
 {Trailblazer::Activity::Right} => <*#<Method: #<Module:0x>.a>>
<*#<Method: #<Module:0x>.a>>
 {Trailblazer::Activity::Right} => #<End/:success>
#<End/:success>
}

    signal, (ctx, _) = impl.([seq: []])

    signal.inspect.must_equal %{#<Trailblazer::Activity::End semantic=:success>}
    ctx.inspect.must_equal %{{:seq=>[:a]}}
  end
end
