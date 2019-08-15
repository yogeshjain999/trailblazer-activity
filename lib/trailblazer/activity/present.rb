module Trailblazer
  class Activity
    # Task < Array
    # [ input, ..., output ]

    module Trace
      # TODO: make this simpler.
      module Present
        module_function

        INDENTATION = "   |".freeze
        STEP_PREFIX = "-- ".freeze

        def default_renderer(step:, previous_step:, next_step:)
          [ step[:level], %{#{step[:name]}} ]
        end

        def call(stack, level: 1, tree: [], renderer: method(:default_renderer), **options)
          tree(stack.to_a, level, tree: tree, renderer: renderer, **options)
        end

        def tree(stack, level, tree:, renderer:, **options)
          tree_for(stack, level, options.merge(tree: tree))

          steps = tree.each_with_index.map do |step, index|
            renderer.(step: step, previous_step: tree[index - 1], next_step: tree[index + 1])
          end

          render_tree_for(steps)
        end

        def render_tree_for(steps)
          steps.map { |level, step|
            indentation = INDENTATION * (level -1)
            indentation = indentation[0...-1] + "`" if level == 1 || /End./.match(step) # start or end step
            indentation + STEP_PREFIX + step
          }.join("\n")
        end

        def tree_for(stack, level, tree:, **options)
          stack.each do |lvl| # always a Stack::Task[input, ..., output]
            input, output, nested = Trace::Level.input_output_nested_for_level(lvl)

            task = input.task

            graph = Introspect::Graph(input.activity)

            name = (node = graph.find { |node| node[:task] == task }) ? node[:id] : task
            name ||= task # FIXME: bullshit

            tree << { level: level, input: input, output: output, name: name, **options }

            if nested.any? # nesting
              tree_for(nested, level + 1, options.merge(tree: tree))
            end

            tree
          end
        end
      end
    end
  end
end
