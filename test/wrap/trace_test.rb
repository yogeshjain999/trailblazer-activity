require "test_helper"

class TraceTest < Minitest::Spec
  A = ->(*args) { [ Activity::Right, *args ] }
  B = ->(*args) { [ Activity::Right, *args ] }
  C = ->(*args) { [ Activity::Right, *args ] }
  D = ->(*args) { [ Activity::Right, *args ] }

  let(:activity) do
    intermediate = Inter.new(
      {
        Inter::TaskRef("Start.default") => [Inter::Out(:success, :B)],
        Inter::TaskRef(:B) => [Inter::Out(:success, :D)],
        Inter::TaskRef(:D) => [Inter::Out(:success, :E)],
        Inter::TaskRef(:E) => [Inter::Out(:success, "End.success")],
        Inter::TaskRef("End.success", stop_event: true) => [Inter::Out(:success, nil)]
      },
      [Inter::TaskRef("End.success")],
      [Inter::TaskRef("Start.default")] # start
    )

    implementation = {
      "Start.default" => Schema::Implementation::Task(st = implementing::Start, [Activity::Output(Activity::Right, :success)],        [TaskWrap::Extension.new(task: st, merge: TaskWrap.method(:initial_wrap_static))]),
      :B => Schema::Implementation::Task(b = implementing.method(:b), [Activity::Output(Activity::Right, :success)],                  [TaskWrap::Extension.new(task: b, merge: TaskWrap.method(:initial_wrap_static))]),
      :D => Schema::Implementation::Task(c = bc, [Activity::Output(implementing::Success, :success)],                  [TaskWrap::Extension.new(task: c, merge: TaskWrap.method(:initial_wrap_static))]),
      :E => Schema::Implementation::Task(e = implementing.method(:f), [Activity::Output(Activity::Right, :success)],                  [TaskWrap::Extension.new(task: e, merge: TaskWrap.method(:initial_wrap_static))]),
      "End.success" => Schema::Implementation::Task(_es = implementing::Success, [Activity::Output(implementing::Success, :success)], [TaskWrap::Extension.new(task: _es, merge: TaskWrap.method(:initial_wrap_static))]), # DISCUSS: End has one Output, signal is itself?
    }

    schema = Inter.(intermediate, implementation)

    Activity.new(schema)
  end

  let(:bc) do
     intermediate = Inter.new(
      {
        Inter::TaskRef("Start.default") => [Inter::Out(:success, :B)],
        Inter::TaskRef(:B) => [Inter::Out(:success, :C)],
        Inter::TaskRef(:C) => [Inter::Out(:success, "End.success")],
        Inter::TaskRef("End.success", stop_event: true) => [Inter::Out(:success, nil)]
      },
      [Inter::TaskRef("End.success")],
      [Inter::TaskRef("Start.default")], # start
    )

    implementation = {
      "Start.default" => Schema::Implementation::Task(st = implementing::Start, [Activity::Output(Activity::Right, :success)],        [TaskWrap::Extension.new(task: st, merge: TaskWrap.method(:initial_wrap_static))]),
      :B => Schema::Implementation::Task(b = implementing.method(:b), [Activity::Output(Activity::Right, :success)],                  [TaskWrap::Extension.new(task: b, merge: TaskWrap.method(:initial_wrap_static))]),
      :C => Schema::Implementation::Task(c = implementing.method(:c), [Activity::Output(Activity::Right, :success)],                  [TaskWrap::Extension.new(task: c, merge: TaskWrap.method(:initial_wrap_static))]),
      "End.success" => Schema::Implementation::Task(_es = implementing::Success, [Activity::Output(implementing::Success, :success)], [TaskWrap::Extension.new(task: _es, merge: TaskWrap.method(:initial_wrap_static))]), # DISCUSS: End has one Output, signal is itself?
    }

    schema = Inter.(intermediate, implementation)

    Activity.new(schema)
  end

  it do
    activity.({})
  end

  it "traces flat activity" do
    stack, signal, (options, flow_options), _ = Trailblazer::Activity::Trace.invoke( bc,
      [
        { seq: [] },
        { flow: true }
      ]
    )

    signal.class.inspect.must_equal %{Trailblazer::Activity::End}
    options.inspect.must_equal %{{:seq=>[:b, :c]}}
    flow_options[:flow].inspect.must_equal %{true}

    output = Trailblazer::Activity::Trace::Present.(stack)
    output = output.gsub(/0x\w+/, "").gsub(/0x\w+/, "").gsub(/@.+_test/, "")

    output.must_equal %{`-- #<Trailblazer::Activity:>
    |-- Start.default
    |-- B
    |-- C
    `-- End.success}
  end

  it "allows nested tracing" do
    stack, _ = Trailblazer::Activity::Trace.invoke( activity,
      [
        { seq: [] },
        {}
      ]
    )

    output = Trailblazer::Activity::Trace::Present.(stack)

    puts output = output.gsub(/0x\w+/, "").gsub(/0x\w+/, "").gsub(/@.+_test/, "")

    output.must_equal %{`-- #<Trailblazer::Activity:>
    |-- Start.default
    |-- B
    |-- D
    |   |-- Start.default
    |   |-- B
    |   |-- C
    |   `-- End.success
    |-- E
    `-- End.success}
  end

  it "Present allows to inject :renderer and pass through additional arguments to the renderer" do
    stack, _ = Trailblazer::Activity::Trace.invoke( activity,
      [
        { seq: [] },
        {}
      ]
    )

    renderer = ->(level:, input:, name:, color:, **) { [level, %{#{level}/#{input.task}/#{name}/#{color}}] }

    output = Trailblazer::Activity::Trace::Present.(stack, renderer: renderer,
      color: "pink" # additional options.
    )

    output = output.gsub(/0x\w+/, "").gsub(/0x\w+/, "").gsub(/@.+_test/, "")

    output.must_equal %{`-- 1/#<Trailblazer::Activity:>/#<Trailblazer::Activity:>/pink
    |-- 2/#<Trailblazer::Activity::Start semantic=:default>/Start.default/pink
    |-- 2/#<Method: #<Module:>.b>/B/pink
    |-- 2/#<Trailblazer::Activity:>/D/pink
    |   |-- 3/#<Trailblazer::Activity::Start semantic=:default>/Start.default/pink
    |   |-- 3/#<Method: #<Module:>.b>/B/pink
    |   |-- 3/#<Method: #<Module:>.c>/C/pink
    |   `-- 3/#<Trailblazer::Activity::End semantic=:success>/End.success/pink
    |-- 2/#<Method: #<Module:>.f>/E/pink
    `-- 2/#<Trailblazer::Activity::End semantic=:success>/End.success/pink}
  end

  it "allows to inject custom :stack" do
    skip "this test goes to the developer gem"
    stack = Trailblazer::Activity::Trace::Stack.new

    begin
    returned_stack, _ = Trailblazer::Activity::Trace.invoke( activity,
      [
        { content: "Let's start writing" },
        { stack: stack }
      ]
    )
  rescue
    # pp stack
        puts Trailblazer::Activity::Trace::Present.(stack)

  end

    returned_stack.must_equal stack
  end
end
